// backend/src/main/java/com/nemo/backend/domain/photo/service/PhotoServiceImpl.java
package com.nemo.backend.domain.photo.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nemo.backend.domain.photo.dto.PhotoDownloadUrlDto;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.dto.SelectedPhotosDownloadUrlsResponse;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.domain.photo.repository.PhotoRepository;
import com.nemo.backend.domain.album.entity.AlbumShare;
import com.nemo.backend.domain.album.repository.AlbumShareRepository;
import com.nemo.backend.domain.storage.service.StorageService;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import lombok.extern.slf4j.Slf4j;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.util.*;
import java.util.HexFormat;
import java.util.Iterator;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Base64;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

import static com.nemo.backend.domain.photo.service.S3PhotoStorage.StorageException;

@Slf4j
@Service
@Transactional
public class PhotoServiceImpl implements PhotoService {

    private static final int CONNECT_TIMEOUT_MS = 5000;
    private static final int READ_TIMEOUT_MS    = 10000;
    private static final int MAX_REDIRECTS      = 5;
    private static final int MAX_HTML_FOLLOW    = 2;
    private static final long MAX_BYTES         = 50L * 1024 * 1024;
    private static final String USER_AGENT      = "Mozilla/5.0 Nemo/1.0";
    private static final int MIN_IMAGE_BYTES    = 5 * 1024;

    private static final ObjectMapper JSON = new ObjectMapper();

    private final PhotoRepository photoRepository;
    private final PhotoStorage storage;
    private final AlbumShareRepository albumShareRepository;
    private final String publicBaseUrl;
    private final StorageService storageService;

    public PhotoServiceImpl(PhotoRepository photoRepository,
                            PhotoStorage storage,
                            AlbumShareRepository albumShareRepository,
                            @Value("${app.public-base-url:http://localhost:8080}") String publicBaseUrl, StorageService storageService) {
        this.photoRepository = photoRepository;
        this.storage = storage;
        this.albumShareRepository = albumShareRepository;
        this.storageService = storageService;
        this.publicBaseUrl = publicBaseUrl.replaceAll("/+$", "");
    }

    private String toPublicUrl(String key) {
        return String.format("%s/files/%s", publicBaseUrl, key);
    }

    // ========================================================
    // 1) QR/갤러리 혼합 업로드 (location / memo 저장, video는 DB에 안 넣음)
    // ========================================================
    @Override
    public PhotoResponseDto uploadHybrid(Long userId,
                                         String qrUrlOrPayload,
                                         MultipartFile image,
                                         String brand,
                                         String location,
                                         LocalDateTime takenAt,
                                         String tagListJson,
                                         String friendIdListJson,
                                         String memo) {

        log.info("[QR][uploadHybrid] userId={}, brand={}, qr='{}', hasImage={}, imageName={}",
                userId,
                brand,
                qrUrlOrPayload,
                (image != null && !image.isEmpty()),
                (image != null ? image.getOriginalFilename() : null)
        );

        storageService.checkPhotoLimitOrThrow(userId);

        if ((qrUrlOrPayload == null || qrUrlOrPayload.isBlank()) && (image == null || image.isEmpty())) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "image 또는 qrUrl/qrCode 중 하나는 필수입니다.");
        }

        // 🔥 QR 중복 차단 로직 제거됨

        String storedImage;
        String storedThumb;

        if (image != null && !image.isEmpty()) {
            try {
                String key = storage.store(image);
                String url = toPublicUrl(key);
                storedImage = url;
                storedThumb = url;
            } catch (ApiException ae) {
                if (ae.getErrorCode() == ErrorCode.INVALID_ARGUMENT && looksLikeUrl(qrUrlOrPayload)) {
                    AssetPair ap = fetchAssetsFromQrPayload(qrUrlOrPayload);
                    storedImage = ap.imageUrl;
                    storedThumb = ap.thumbnailUrl != null ? ap.thumbnailUrl : ap.imageUrl;
                    if (takenAt == null) takenAt = ap.takenAt;
                } else {
                    throw ae;
                }
            } catch (Exception e) {
                throw new ApiException(ErrorCode.STORAGE_FAILED, "파일 저장 실패: " + e.getMessage(), e);
            }
        } else {
            if (!looksLikeUrl(qrUrlOrPayload)) {
                throw new InvalidQrException("지원하지 않는 QR/URL 포맷입니다.");
            }
            AssetPair ap = fetchAssetsFromQrPayload(qrUrlOrPayload);
            storedImage = ap.imageUrl;
            storedThumb = ap.thumbnailUrl != null ? ap.thumbnailUrl : ap.imageUrl;
            if (takenAt == null) takenAt = ap.takenAt;
        }

        if (brand == null || brand.isBlank()) {
            brand = (qrUrlOrPayload != null) ? inferBrand(qrUrlOrPayload) : "기타";
        }
        if (takenAt == null) takenAt = LocalDateTime.now();

        Photo photo = new Photo(
                userId,
                storedImage,
                storedThumb,
                brand,
                takenAt,
                location
        );
        photo.setMemo(memo);

        Photo saved = photoRepository.save(photo);
        return new PhotoResponseDto(saved);
    }

    // ========================================================
    // 2) 사진 목록 조회 (favorite + brand + tag 필터)
    // ========================================================
    @Override
    @Transactional(readOnly = true)
    public Page<PhotoResponseDto> list(Long userId,
                                       Pageable pageable,
                                       Boolean favorite,
                                       String brand,
                                       String tag) {

        Page<Photo> page = photoRepository.findForList(userId, favorite, brand, tag, pageable);
        return page.map(PhotoResponseDto::new);
    }

    // 기존 시그니처도 그대로 유지 (interface default랑 맞춰줌)
    @Override
    @Transactional(readOnly = true)
    public Page<PhotoResponseDto> list(Long userId, Pageable pageable, Boolean favorite) {
        return list(userId, pageable, favorite, null, null);
    }

    @Transactional(readOnly = true)
    public Page<PhotoResponseDto> list(Long userId, Pageable pageable) {
        return list(userId, pageable, null, null, null);
    }

    // ========================================================
    // 3) 사진 삭제
    // ========================================================
    @Override
    public void delete(Long userId, Long photoId) {
        Photo photo = photoRepository.findByIdAndDeletedIsFalse(photoId)
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_ARGUMENT, "존재하지 않는 사진입니다."));
        if (!photo.getUserId().equals(userId)) {
            throw new ApiException(ErrorCode.UNAUTHORIZED, "삭제 권한이 없습니다.");
        }

        // ===== S3 저장소에서 실제 파일 삭제 (best-effort) =====
        try {
            String imageKey = extractStorageKeyFromUrl(photo.getImageUrl());
            String thumbKey = extractStorageKeyFromUrl(photo.getThumbnailUrl());

            if (imageKey != null) {
                storage.delete(imageKey);
            }
            if (thumbKey != null && !thumbKey.equals(imageKey)) {
                storage.delete(thumbKey);
            }
        } catch (Exception e) {
            // S3 삭제 실패해도 서비스 전체 장애로 가지 않게 워닝만 남기고 넘어감
            log.warn("[PHOTO][delete] S3 삭제 실패 photoId={}, err={}", photoId, e.toString());
        }
        // ===== 여기까지 S3 삭제 =====

        photo.setDeleted(true);
        photoRepository.save(photo);
    }

    // ========================================================
    // 4) 사진 상세 조회
    // ========================================================
    @Override
    @Transactional(readOnly = true)
    public PhotoResponseDto getDetail(Long userId, Long photoId) {
        Photo photo = photoRepository.findByIdAndDeletedIsFalse(photoId)
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_ARGUMENT, "해당 사진을 찾을 수 없습니다."));

        if (!hasPhotoAccess(userId, photo)) {
            // 명세상 403 Forbidden 사용 :contentReference[oaicite:4]{index=4}
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 사진에 접근할 권한이 없습니다.");
        }
        return new PhotoResponseDto(photo);
    }

    // ========================================================
    // 5) 사진 상세 정보 수정 (촬영일시, 위치, 브랜드, 메모)
    // ========================================================
    @Override
    public PhotoResponseDto updateDetails(Long userId,
                                          Long photoId,
                                          LocalDateTime takenAt,
                                          String location,
                                          String brand,
                                          String memo) {

        Photo photo = photoRepository.findByIdAndDeletedIsFalse(photoId)
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_ARGUMENT, "해당 사진을 찾을 수 없습니다."));
        if (!photo.getUserId().equals(userId)) {
            throw new ApiException(ErrorCode.UNAUTHORIZED, "이 사진을 수정할 권한이 없습니다.");
        }

        if (takenAt != null) {
            photo.setTakenAt(takenAt);
        }
        if (location != null) {
            photo.setLocation(location);
        }
        if (brand != null && !brand.isBlank()) {
            photo.setBrand(brand);
        }
        if (memo != null) {
            photo.setMemo(memo);
        }

        Photo saved = photoRepository.save(photo);
        return new PhotoResponseDto(saved);
    }

    // ========================================================
    // 6) 즐겨찾기 토글
    // ========================================================
    @Override
    public boolean toggleFavorite(Long userId, Long photoId) {
        Photo photo = photoRepository.findByIdAndDeletedIsFalse(photoId)
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_ARGUMENT, "해당 사진을 찾을 수 없습니다."));

        if (!hasPhotoAccess(userId, photo)) {
            // 명세상 403 Forbidden + 메시지도 스펙에 맞는 형태로 :contentReference[oaicite:5]{index=5}
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 사진에 대해 즐겨찾기 권한이 없습니다.");
        }

        boolean current = Boolean.TRUE.equals(photo.getFavorite());
        boolean next = !current;
        photo.setFavorite(next);
        photoRepository.save(photo);
        return next;
    }


    // ========================================================
    // 7) 선택 사진 다운로드 URL 목록 조회
    // ========================================================
    @Override
    @Transactional(readOnly = true)
    public SelectedPhotosDownloadUrlsResponse getDownloadUrls(Long userId, List<Long> photoIdList) {
        if (photoIdList == null || photoIdList.isEmpty()) {
            // ✅ 명세: INVALID_REQUEST
            throw new ApiException(
                    ErrorCode.INVALID_REQUEST,
                    "photoIdList는 비어 있을 수 없습니다."
            );
        }

        // 중복 제거
        List<Long> distinctIds = photoIdList.stream()
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());

        List<Photo> photos = photoRepository.findAllById(distinctIds);

        List<PhotoDownloadUrlDto> items = photos.stream()
                .filter(p -> Boolean.FALSE.equals(p.getDeleted()))
                // ✅ 권한: 내 사진 + 공유 앨범(ACCEPTED) 멤버
                .filter(p -> hasPhotoAccess(userId, p))
                .map(p -> {
                    String downloadUrl = p.getImageUrl();
                    String filename = buildDownloadFilename(p.getImageUrl(), p.getId());
                    Long fileSize = resolveFileSizeFromImageUrl(p.getImageUrl());

                    return PhotoDownloadUrlDto.builder()
                            .photoId(p.getId())
                            .downloadUrl(downloadUrl)
                            .filename(filename)
                            .fileSize(fileSize)
                            .build();
                })
                .toList();

        if (items.isEmpty()) {
            // ✅ 명세: NO_DOWNLOADABLE_PHOTOS(404)
            throw new ApiException(
                    ErrorCode.NO_DOWNLOADABLE_PHOTOS,
                    "다운로드 가능한 사진이 없습니다."
            );
        }

        return SelectedPhotosDownloadUrlsResponse.builder()
                .photos(items)
                .build();
    }


    /** download용 파일 이름 생성 – URL 확장자 기준, 없으면 .jpg */
    private String buildDownloadFilename(String imageUrl, Long photoId) {
        String ext = "jpg";
        if (imageUrl != null) {
            try {
                String path = new URL(imageUrl).getPath();
                String name = path.substring(path.lastIndexOf('/') + 1);
                int dot = name.lastIndexOf('.');
                if (dot > 0 && dot < name.length() - 1) {
                    ext = name.substring(dot + 1);
                }
            } catch (Exception ignored) {
            }
        }
        return "nemo_photo_" + photoId + "." + ext;
    }

    /** imageUrl → S3 key 추출 후, S3에서 파일 크기 조회 */
    private Long resolveFileSizeFromImageUrl(String imageUrl) {
        String key = extractStorageKeyFromUrl(imageUrl);
        if (key == null) return null;

        if (storage instanceof S3PhotoStorage s3) {
            try {
                return s3.getObjectSize(key);
            } catch (Exception e) {
                log.warn("[PHOTO][download] 파일 크기 조회 실패 key={}, err={}", key, e.toString());
                return null;
            }
        }
        return null;
    }

    /**
     * publicBaseUrl + "/files/{key}" 형태의 URL에서 S3 key만 추출
     * 예: http://localhost:8080/files/albums/2025-11-27/xxx.webp
     *  -> albums/2025-11-27/xxx.webp
     */
    private String extractStorageKeyFromUrl(String url) {
        if (url == null || url.isBlank()) return null;

        String base = publicBaseUrl;
        // publicBaseUrl 뒤에 슬래시 여러 개 있으면 제거
        base = base.replaceAll("/+$", "");

        if (!url.startsWith(base)) {
            // 우리 서비스에서 관리하는 URL 형식이 아니면 S3 삭제/용량 조회 안 함
            return null;
        }

        String path = url.substring(base.length()); // "/files/...."
        if (!path.startsWith("/files/")) {
            return null;
        }

        return path.substring("/files/".length()); // "albums/2025-11-27/xxx.webp"
    }

    // ======================================================================
    // 아래부터는 QR 파싱 / HTTP 유틸 / life4cut 전용 로직
    // 🔥 요청대로 알고리즘/로직은 그대로 두고, 사용처만 위에서 조정
    // ======================================================================

    private AssetPair fetchAssetsFromQrPayload(String startUrl) {
        try {
            log.info("[QR][fetch] startUrl={}", startUrl);
            CookieManager cm = new CookieManager(null, CookiePolicy.ACCEPT_ALL);
            CookieHandler.setDefault(cm);

            LinkedHashSet<String> visited = new LinkedHashSet<>();
            String current = startUrl;
            int htmlFollow = 0;
            String foundImage = null, foundVideo = null, foundThumb = null;

            for (int redirects = 0; redirects <= MAX_REDIRECTS; redirects++) {
                String norm = normalizeUrl(current);
                if (!visited.add(norm)) {
                    throw new IOException("Redirect loop: " + current);
                }

                log.info("[QR][fetch] step={}, current={}", redirects, current);

                URL url = new URL(current);

                // ✅ Photogray 전용: photogray-download.aprd.io?id=... 이면 바로 sessionId 기반으로 처리
                AssetPair photogray = tryResolvePhotograyFromId(url);
                if (photogray != null) {
                    log.info("[QR][photogray] resolved directly from id param: {}", url);
                    return photogray;
                }

                HttpURLConnection conn = open(current, "GET", null, startUrl);
                int code = conn.getResponseCode();

                if (code / 100 == 3) {
                    String location = conn.getHeaderField("Location");
                    if (location == null || location.isBlank()) {
                        throw new IOException("Redirect without Location");
                    }
                    current = new URL(url, location).toString();
                    continue;
                }

                if (code < 200 || code >= 300) {
                    throw new IOException("HTTP " + code + " from " + current);
                }

                String contentType = safeLower(conn.getContentType());
                String cd = conn.getHeaderField("Content-Disposition");
                boolean isAttachment = cd != null && cd.toLowerCase(Locale.ROOT).contains("attachment");

                String specialNext = resolveLife4cutNextUrl(url);
                if (specialNext != null && !isSamePage(specialNext, current)) {
                    log.info("[QR][life4cut][forceJump] {} -> {}", current, specialNext);
                    current = specialNext;
                    continue;
                }

                if ((contentType != null &&
                        (contentType.startsWith("image/") || contentType.startsWith("video/")))
                        || isAttachment) {

                    try (InputStream in = boundedStream(conn)) {
                        byte[] data = in.readAllBytes();
                        String ct = (contentType != null) ? contentType : "application/octet-stream";

                        if (ct.startsWith("image/")) {
                            ensureValidImageBytes(data);
                            ct = sniffContentType(data, ct);
                            String key = storage.storeBytes(
                                    data,
                                    filenameFromHeadersOrUrl(url, cd, ct),
                                    ct
                            );
                            String publicUrl = toPublicUrl(key);
                            if (foundImage == null) foundImage = publicUrl;
                            if (foundThumb == null)  foundThumb  = publicUrl;
                        } else if (ct.startsWith("video/")) {
                            // 영상도 받아서 스토리지에 저장해 두지만,
                            // 현재 명세상 API/엔티티에는 videoUrl을 노출하거나 저장하지 않는다.
                            String key = storage.storeBytes(
                                    data,
                                    filenameFromHeadersOrUrl(url, cd, ct),
                                    ct
                            );
                            String publicUrl = toPublicUrl(key);
                            if (foundVideo == null) foundVideo = publicUrl;

                            // ✅ Photogray 전용: 같은 폴더의 image.jpg를 추가로 시도
                            if (foundImage == null && isPhotograyResource(url)) {
                                try {
                                    String stillUrl = buildPhotograyImageUrlFromVideo(url);
                                    log.info("[QR][photogray] try still image from video: {}", stillUrl);

                                    HttpURLConnection imgConn = open(stillUrl, "GET", null, startUrl);
                                    int imgCode = imgConn.getResponseCode();
                                    if (imgCode >= 200 && imgCode < 300) {
                                        String imgCt = safeLower(imgConn.getContentType());
                                        if (imgCt != null && imgCt.startsWith("image/")) {
                                            try (InputStream imgIn = boundedStream(imgConn)) {
                                                byte[] imgData = imgIn.readAllBytes();
                                                ensureValidImageBytes(imgData);
                                                String realCt = sniffContentType(imgData, imgCt);
                                                String imgKey = storage.storeBytes(
                                                        imgData,
                                                        filenameFromHeadersOrUrl(new URL(stillUrl),
                                                                imgConn.getHeaderField("Content-Disposition"),
                                                                realCt),
                                                        realCt
                                                );
                                                String imgPublicUrl = toPublicUrl(imgKey);
                                                foundImage = imgPublicUrl;
                                                if (foundThumb == null) {
                                                    foundThumb = imgPublicUrl;
                                                }
                                                log.info("[QR][photogray] still image stored: {}", imgPublicUrl);
                                            }
                                        } else {
                                            log.warn("[QR][photogray] still image content-type not image: {}", imgCt);
                                        }
                                    } else {
                                        log.warn("[QR][photogray] still image HTTP {} from {}", imgCode, stillUrl);
                                    }
                                } catch (Exception pe) {
                                    log.warn("[QR][photogray] still image fetch failed: {}", pe.toString());
                                }
                            }
                        }
                    } catch (Exception e) {
                        throw new StorageException("파일 저장 실패", e);
                    }

                    break;
                }

                if (contentType != null && contentType.startsWith("text/html")) {
                    if (htmlFollow >= MAX_HTML_FOLLOW) break;

                    String html = readAll(conn.getInputStream());
                    HtmlExtracted he = extractFromHtml(html, current);

                    if (he.imageUrl != null && !isSamePage(he.imageUrl, current)) {
                        current = new URL(url, he.imageUrl).toString();
                        htmlFollow++;
                        continue;
                    }
                    break;
                }

                break;
            }

            if (foundImage == null && foundVideo == null) {
                throw new IOException("이미지/영상 URL을 찾지 못했습니다.");
            }
            if (foundThumb == null) foundThumb = foundImage;

            return new AssetPair(foundImage, foundThumb, foundVideo, null);
        } catch (StorageException e) {
            throw e;
        } catch (Exception e) {
            throw new ApiException(ErrorCode.UPSTREAM_FAILED,
                    "원격 자산 추출 실패: " + e.getMessage(), e);
        }
    }

    // ===================== Photogray 유틸 =====================

    /** pg-qr-resource.aprd.io 의 video/mp4 인지 확인 */
    private boolean isPhotograyResource(URL url) {
        if (url == null || url.getHost() == null) return false;
        String host = url.getHost().toLowerCase(Locale.ROOT);
        String path = (url.getPath() == null) ? "" : url.getPath().toLowerCase(Locale.ROOT);
        return host.contains("pg-qr-resource.aprd.io") && path.endsWith("/video.mp4");
    }

    /** https://pg-qr-resource.aprd.io/.../video.mp4 → .../image.jpg */
    private String buildPhotograyImageUrlFromVideo(URL videoUrl) {
        String path = videoUrl.getPath();
        int idx = path.lastIndexOf('/');
        String baseDir = (idx >= 0) ? path.substring(0, idx) : "";
        String imgPath = baseDir + "/image.jpg";

        StringBuilder sb = new StringBuilder();
        sb.append(videoUrl.getProtocol())
                .append("://")
                .append(videoUrl.getHost());
        if (videoUrl.getPort() != -1 && videoUrl.getPort() != videoUrl.getDefaultPort()) {
            sb.append(":").append(videoUrl.getPort());
        }
        sb.append(imgPath);
        return sb.toString();
    }

    /**
     * photogray-download.aprd.io?id=... 형태의 URL에서
     * id(base64) → sessionId → pg-qr-resource.aprd.io/{sessionId}/image.jpg / video.mp4 를
     * 직접 호출해서 AssetPair를 만들어 준다.
     */
    private AssetPair tryResolvePhotograyFromId(URL url) {
        if (url == null || url.getHost() == null) return null;

        String host = url.getHost().toLowerCase(Locale.ROOT);
        if (!host.contains("photogray-download.aprd.io")) {
            return null;
        }

        String query = url.getQuery();
        if (query == null || query.isBlank()) return null;

        // 1) query에서 id 파라미터 추출
        String encodedId = null;
        for (String pair : query.split("&")) {
            int idx = pair.indexOf('=');
            if (idx <= 0) continue;
            String key = pair.substring(0, idx);
            String value = pair.substring(idx + 1);
            if ("id".equals(key)) {
                encodedId = value;
                break;
            }
        }
        if (encodedId == null || encodedId.isBlank()) return null;

        try {
            // 2) base64 디코딩 → sessionId=...&mode=...&... 문자열
            String decoded = new String(Base64.getDecoder().decode(encodedId), StandardCharsets.UTF_8);
            String sessionId = null;
            for (String pair : decoded.split("&")) {
                int idx = pair.indexOf('=');
                if (idx <= 0) continue;
                String key = pair.substring(0, idx);
                String value = pair.substring(idx + 1);
                if ("sessionId".equals(key)) {
                    sessionId = value;
                    break;
                }
            }

            if (sessionId == null || sessionId.isBlank()) {
                log.warn("[QR][photogray] sessionId not found in decoded: {}", decoded);
                return null;
            }

            // 3) resource base URL 구성
            String base = "https://pg-qr-resource.aprd.io/" + sessionId;
            String imageUrl = base + "/image.jpg";
            String videoUrl = base + "/video.mp4";

            String storedImage = null;
            String storedThumb = null;
            String storedVideo = null;

            // 3-1) image.jpg 먼저 시도 (사진)
            try {
                HttpURLConnection imgConn = open(imageUrl, "GET", null, url.toString());
                int code = imgConn.getResponseCode();
                if (code >= 200 && code < 300) {
                    String imgCtHeader = safeLower(imgConn.getContentType());
                    try (InputStream imgIn = boundedStream(imgConn)) {
                        byte[] imgData = imgIn.readAllBytes();

                        try {
                            // 헤더가 octet-stream 이라도 바이트 검사해서 진짜 이미지인지 확인
                            ensureValidImageBytes(imgData);
                        } catch (IOException ex) {
                            log.warn("[QR][photogray] direct image not recognized as image bytes: {}", ex.getMessage());
                            // 이미지가 아니면 Photogray 특수 처리 포기 → 일반 로직으로 넘기기
                            return null;
                        }

                        String realCt = sniffContentType(imgData, imgCtHeader);
                        String imgKey = storage.storeBytes(
                                imgData,
                                filenameFromHeadersOrUrl(new URL(imageUrl),
                                        imgConn.getHeaderField("Content-Disposition"),
                                        realCt),
                                realCt
                        );
                        storedImage = toPublicUrl(imgKey);
                        storedThumb = storedImage;
                        log.info("[QR][photogray] direct image stored: {} (ct={})", storedImage, realCt);
                    }
                } else {
                    log.warn("[QR][photogray] direct image HTTP {} from {}", code, imageUrl);
                }

            } catch (Exception e) {
                log.warn("[QR][photogray] direct image fetch failed: {}", e.toString());
            }

            // 3-2) video.mp4 는 선택적으로 저장 (지금은 DB에 안 넣지만, 나중 확장 대비)
            try {
                HttpURLConnection vConn = open(videoUrl, "GET", null, url.toString());
                int vCode = vConn.getResponseCode();
                if (vCode >= 200 && vCode < 300) {
                    String vCt = safeLower(vConn.getContentType());
                    if (vCt != null && vCt.startsWith("video/")) {
                        try (InputStream vIn = boundedStream(vConn)) {
                            byte[] vData = vIn.readAllBytes();
                            String vKey = storage.storeBytes(
                                    vData,
                                    filenameFromHeadersOrUrl(new URL(videoUrl),
                                            vConn.getHeaderField("Content-Disposition"),
                                            vCt),
                                    vCt
                            );
                            storedVideo = toPublicUrl(vKey);
                            log.info("[QR][photogray] direct video stored: {}", storedVideo);
                        }
                    }
                }
            } catch (Exception e) {
                log.warn("[QR][photogray] direct video fetch failed: {}", e.toString());
            }

            if (storedImage == null && storedVideo == null) {
                // 둘 다 실패하면 Photogray 특수 처리 포기 → 기존 일반 로직으로 진행
                return null;
            }

            if (storedThumb == null) storedThumb = storedImage;
            return new AssetPair(storedImage, storedThumb, storedVideo, null);

        } catch (IllegalArgumentException e) {
            log.warn("[QR][photogray] base64 decode failed for id={}", encodedId);
            return null;
        } catch (Exception e) {
            log.warn("[QR][photogray] unexpected error: {}", e.toString());
            return null;
        }
    }



    // ===================== life4cut 전용 webQr → S3 처리 =====================

    // 인생네컷 전용: download.life4cut.net/webQr 의 쿼리 파라미터에서
    // bucket + folderPath 를 뽑아서 S3 직결 이미지 URL을 만든다.
    private String resolveLife4cutNextUrl(URL webQrUrl) {
        try {
            String host  = webQrUrl.getHost();
            String path  = webQrUrl.getPath();
            String query = webQrUrl.getQuery();

            if (host == null || path == null) return null;

            String lowerHost = host.toLowerCase(Locale.ROOT);

            // life4cut 도메인 + webQr 경로가 아니면 무시
            if (!lowerHost.contains("life4cut")) return null;
            if (!path.contains("webQr")) return null;
            if (query == null || query.isBlank()) return null;

            // 🔍 쿼리스트링에서 bucket / folderPath 추출
            String bucket = null;
            String folderPath = null;

            String[] pairs = query.split("&");
            for (String pair : pairs) {
                int idx = pair.indexOf('=');
                if (idx <= 0) continue;

                String key = URLDecoder.decode(pair.substring(0, idx), StandardCharsets.UTF_8);
                String value = URLDecoder.decode(pair.substring(idx + 1), StandardCharsets.UTF_8);

                if ("bucket".equals(key)) {
                    bucket = value;
                } else if ("folderPath".equals(key)) {
                    folderPath = value;
                }
            }

            if (bucket == null || folderPath == null) {
                log.info("[QR][life4cut] missing bucket/folderPath in query: {}", query);
                return null;
            }

            if (!folderPath.startsWith("/")) {
                folderPath = "/" + folderPath;
            }

            String s3Url = "https://" + bucket + ".s3.ap-northeast-2.amazonaws.com"
                    + folderPath
                    + "/image.jpg";

            log.info("[QR][life4cut] webQr={} -> directS3={}", webQrUrl, s3Url);

            return s3Url;
        } catch (Exception e) {
            log.warn("[QR][life4cut] resolve error for {}: {}", webQrUrl, e.toString());
            return null;
        }
    }

    /**
     * webQrJson 응답 문자열에서 S3 QRimage URL을 직접 찾는다.
     */
    private String extractLife4cutUrlFromText(String text) {
        if (text == null || text.isEmpty()) return null;

        // JSON 문자열 안의 \/ 를 / 로 먼저 보정
        String normalized = text.replace("\\/", "/");

        Pattern p = Pattern.compile(
                "(https?://[^\"'\\s]+/(?:QRimage|qrimage)[^\"'\\s]+\\.(?:jpg|jpeg|png|webp|mp4|webm|mov))",
                Pattern.CASE_INSENSITIVE
        );
        Matcher m = p.matcher(normalized);
        if (m.find()) {
            return m.group(1);
        }
        return null;
    }

    /**
     * JSON 트리를 재귀 순회하며 QRimage 가 들어간 미디어 경로를 찾는다.
     */
    private String findLife4cutMediaRecursive(JsonNode node) {
        if (node == null) return null;

        if (node.isTextual()) {
            String v = node.asText();
            String candidate = v.replace("\\/", "/");
            if (looksLikeLife4cutMedia(candidate)) {
                return candidate;
            }
        }

        if (node.isArray()) {
            for (JsonNode child : node) {
                String r = findLife4cutMediaRecursive(child);
                if (r != null) return r;
            }
        } else if (node.isObject()) {
            Iterator<JsonNode> it = node.elements();
            while (it.hasNext()) {
                String r = findLife4cutMediaRecursive(it.next());
                if (r != null) return r;
            }
        }

        return null;
    }

    private boolean looksLikeLife4cutMedia(String s) {
        if (s == null) return false;
        String lower = s.toLowerCase(Locale.ROOT);

        if (!lower.contains("qrimage")) return false;

        return lower.endsWith(".jpg") || lower.endsWith(".jpeg") ||
                lower.endsWith(".png") || lower.endsWith(".webp") ||
                lower.endsWith(".mp4") || lower.endsWith(".webm") ||
                lower.endsWith(".mov");
    }

    // ===================== HTTP 유틸 =====================

    private HttpURLConnection open(String url, String method, String body, String referer) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setInstanceFollowRedirects(false);
        conn.setConnectTimeout(CONNECT_TIMEOUT_MS);
        conn.setReadTimeout(READ_TIMEOUT_MS);
        conn.setRequestProperty("User-Agent", USER_AGENT);
        conn.setRequestProperty("Accept", "image/jpeg,image/png,image/webp;q=0.9,text/html;q=0.8,*/*;q=0.5");
        conn.setRequestProperty("Accept-Language", "ko,en;q=0.8");
        if (referer != null) conn.setRequestProperty("Referer", referer);
        conn.setRequestMethod(method);
        if ("POST".equalsIgnoreCase(method) && body != null) {
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8");
            conn.setRequestProperty("Content-Length", String.valueOf(bytes.length));
            try (OutputStream os = conn.getOutputStream()) { os.write(bytes); }
        }
        conn.connect();
        return conn;
    }

    // ===================== HTML 파서 & 유틸 =====================

    private HtmlExtracted extractFromHtml(String html, String baseUrl) {
        Document doc = Jsoup.parse(html, baseUrl);
        HtmlExtracted out = new HtmlExtracted();

        // 1) 다운로드 링크 우선
        Element aDownload = doc.selectFirst(
                "a[download], a[href*='download'], a.btn-download, a#download, a.button, " +
                        "a[href$='.jpg'], a[href$='.jpeg'], a[href$='.png'], a[href$='.webp'], " +
                        "a[href$='.mp4'], a[href$='.webm'], a[href$='.mov']"
        );
        if (aDownload != null) {
            out.imageUrl = aDownload.absUrl("href");
        }

        // 2) picture > source[srcset] (JPEG 우선)
        if (out.imageUrl == null) {
            Element jpeg = doc.selectFirst("picture source[type*=jpeg][srcset], picture source[type*=jpg][srcset]");
            Element any  = (jpeg != null) ? jpeg : doc.selectFirst("picture source[srcset]");
            if (any != null) {
                out.imageUrl = pickBestFromSrcset(any.attr("srcset"), doc.baseUri());
            }
        }

        // 3) img[srcset]
        if (out.imageUrl == null) {
            Element imgSrcset = doc.selectFirst("img[srcset]");
            if (imgSrcset != null) {
                out.imageUrl = pickBestFromSrcset(imgSrcset.attr("srcset"), imgSrcset.baseUri());
            }
        }

        // 4) JSON-LD 안의 이미지/영상 URL
        if (out.imageUrl == null) {
            for (Element s : doc.select("script[type=application/ld+json]")) {
                String j = s.data();
                String u = firstUrlFromJsonLd(j);
                if (u != null) {
                    out.imageUrl = u;
                    break;
                }
            }
        }

        // 5) video poster/source
        if (out.imageUrl == null) {
            Element video = doc.selectFirst("video[poster]");
            if (video != null) {
                out.imageUrl = video.absUrl("poster");
            }
            if (out.imageUrl == null) {
                Element vsrc = doc.selectFirst("video source[src]");
                if (vsrc != null) {
                    out.imageUrl = vsrc.absUrl("src");
                }
            }
        }

        // 6) og:image (fallback)
        if (out.imageUrl == null) {
            Element og = doc.selectFirst("meta[property=og:image], meta[name=og:image], meta[itemprop=image]");
            if (og != null) {
                out.imageUrl = og.attr("abs:content");
            }
        }

        // 7) 일반 img[src]
        if (out.imageUrl == null) {
            Element img = doc.selectFirst("img[src]");
            if (img != null) {
                out.imageUrl = img.absUrl("src");
            }
        }

        // 8) 인생네컷 등: HTML/스크립트 안에서 직접 패턴 스캔
        if (out.imageUrl == null && html != null) {
            String lowerHtml = html.toLowerCase(Locale.ROOT);
            String lowerBase = (baseUrl != null) ? baseUrl.toLowerCase(Locale.ROOT) : "";
            boolean looksLife4cut = lowerHtml.contains("life4cut") || lowerBase.contains("life4cut");

            // 8-1) S3 /QRimage/.../image.jpg 같은 직결 URL
            Pattern directImg = Pattern.compile(
                    "https?://[^\"'\\s>]+/(?:qrimage|qr_image|common)/[^\"'\\s>]+\\.(?:jpg|jpeg|png|webp)",
                    Pattern.CASE_INSENSITIVE
            );
            Matcher mDirect = directImg.matcher(html);
            while (mDirect.find()) {
                String candidate = mDirect.group();
                if (!looksLife4cut || candidate.toLowerCase(Locale.ROOT).contains("/qrimage/")) {
                    out.imageUrl = candidate;
                    break;
                }
            }

            // 8-2) download.life4cut.net 의 image?url=%2FQRimage%2F... 형태
            if (out.imageUrl == null && looksLife4cut) {
                Pattern encoded = Pattern.compile(
                        "(/?image\\?url=[^\"'\\s>]+)",
                        Pattern.CASE_INSENSITIVE
                );
                Matcher mEnc = encoded.matcher(html);
                if (mEnc.find()) {
                    out.imageUrl = mEnc.group(1);
                }
            }
        }

        if (out.imageUrl != null && isSamePage(out.imageUrl, baseUrl)) {
            out.imageUrl = null;
        }

        return out;
    }

    private String pickBestFromSrcset(String srcset, String base) {
        if (srcset == null || srcset.isBlank()) return null;
        String[] parts = srcset.split(",");
        int bestW = -1;
        String bestUrl = null;
        for (String p : parts) {
            String[] tok = p.trim().split("\\s+");
            if (tok.length == 0) continue;
            String url = tok[0];
            int w = -1;
            if (tok.length > 1 && tok[1].endsWith("w")) {
                try { w = Integer.parseInt(tok[1].substring(0, tok[1].length() - 1)); } catch (Exception ignored) {}
            }
            if (w > bestW) { bestW = w; bestUrl = url; }
        }
        if (bestUrl == null) return null;
        try { return new URL(new URL(base), bestUrl).toString(); } catch (Exception e) { return bestUrl; }
    }

    private String firstUrlFromJsonLd(String json) {
        if (json == null || json.isBlank()) return null;
        Pattern p = Pattern.compile(
                "(https?:\\\\?/\\\\?/[^\"']+?\\.(?:jpg|jpeg|png|webp|mp4|webm|mov))",
                Pattern.CASE_INSENSITIVE
        );
        Matcher m = p.matcher(json);
        String best = null;
        while (m.find()) {
            String u = m.group(1).replace("\\/", "/");
            if (best == null || u.length() > best.length()) best = u;
        }
        return best;
    }

    // ===================== 기타 유틸 =====================

    private String filenameFromHeadersOrUrl(URL base, String cdHeader, String contentType) {
        return filenameFromHeadersOrUrl(base, cdHeader, contentType, true);
    }

    private String filenameFromHeadersOrUrl(URL base, String cdHeader, String contentType, boolean addExtIfMissing) {
        if (cdHeader != null) {
            Matcher m1 = Pattern.compile("filename\\*=UTF-8''([^;]+)", Pattern.CASE_INSENSITIVE).matcher(cdHeader);
            if (m1.find()) return decodeRFC5987(m1.group(1));
            Matcher m2 = Pattern.compile("filename=\"?([^\";]+)\"?", Pattern.CASE_INSENSITIVE).matcher(cdHeader);
            if (m2.find()) return m2.group(1);
        }
        String path = base.getPath();
        String last = (path == null || path.isBlank()) ? "file" : path.substring(path.lastIndexOf('/') + 1);
        if (last.isBlank()) last = "file";
        if (addExtIfMissing) {
            String low = last.toLowerCase(Locale.ROOT);
            if (!low.contains(".")) {
                if (contentType != null) {
                    if (contentType.contains("jpeg") || contentType.contains("jpg"))      last += ".jpg";
                    else if (contentType.contains("png"))                                last += ".png";
                    else if (contentType.contains("webp"))                               last += ".webp";
                    else if (contentType.contains("mp4"))                                last += ".mp4";
                }
            }
        }
        return last;
    }

    private String decodeRFC5987(String s) {
        try {
            return URLDecoder.decode(s, StandardCharsets.UTF_8);
        } catch (Exception e) {
            return s;
        }
    }

    private String normalizeUrl(String u) {
        try {
            URI uri = new URI(u);
            String scheme = (uri.getScheme() == null ? "https" : uri.getScheme().toLowerCase(Locale.ROOT));
            String host = (uri.getHost() == null ? "" : uri.getHost().toLowerCase(Locale.ROOT));
            int port = uri.getPort();
            String path = (uri.getPath() == null || uri.getPath().isEmpty()) ? "/" : uri.getPath();
            String query = uri.getQuery();
            StringBuilder sb = new StringBuilder();
            sb.append(scheme).append("://").append(host);
            if (port != -1 && port != uri.toURL().getDefaultPort()) sb.append(":").append(port);
            sb.append(path);
            if (query != null) sb.append("?").append(query);
            return sb.toString();
        } catch (Exception e) {
            return u;
        }
    }

    private boolean isSamePage(String candidate, String base) {
        if (candidate == null || base == null) return false;
        try {
            URI a = new URI(candidate), b = new URI(base);
            return a.getHost() != null && b.getHost() != null
                    && a.getHost().equalsIgnoreCase(b.getHost())
                    && ((a.getPath() == null ? "/" : a.getPath())
                    .equals(b.getPath() == null ? "/" : b.getPath()));
        } catch (Exception e) {
            return candidate.equals(base);
        }
    }

    private String safeLower(String s) {
        return (s == null) ? null : s.toLowerCase(Locale.ROOT);
    }

    private String sha256Hex(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(input.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private boolean looksLikeUrl(String s) {
        String t = s.trim().toLowerCase(Locale.ROOT);
        return t.startsWith("http://") || t.startsWith("https://");
    }

    private InputStream boundedStream(HttpURLConnection conn) throws IOException {
        long len = conn.getContentLengthLong();
        if (len > 0 && len > MAX_BYTES) throw new IOException("File too large: " + len);
        return new LimitedInputStream(conn.getInputStream(), MAX_BYTES);
    }

    private static class LimitedInputStream extends java.io.FilterInputStream {
        private long remaining;
        protected LimitedInputStream(InputStream in, long maxBytes) {
            super(in);
            this.remaining = maxBytes;
        }
        @Override public int read() throws IOException {
            if (remaining <= 0) throw new IOException("Limit exceeded");
            int b = super.read();
            if (b != -1) remaining--;
            return b;
        }
        @Override public int read(byte[] b, int off, int len) throws IOException {
            if (remaining <= 0) throw new IOException("Limit exceeded");
            len = (int) Math.min(len, remaining);
            int n = super.read(b, off, len);
            if (n > 0) remaining -= n;
            return n;
        }
    }

    private String readAll(InputStream in) throws IOException {
        return new String(in.readAllBytes(), StandardCharsets.UTF_8);
    }

    private void ensureValidImageBytes(byte[] data) throws IOException {
        if (data == null || data.length < MIN_IMAGE_BYTES) throw new IOException("Image too small");
        if (!looksLikeImage(data)) throw new IOException("Not an image content");
    }

    private static boolean looksLikeImage(byte[] data) {
        if (data == null || data.length < 12) return false;
        // JPEG
        if ((data[0] & 0xFF) == 0xFF && (data[1] & 0xFF) == 0xD8 && (data[2] & 0xFF) == 0xFF) return true;
        // PNG
        if ((data[0] & 0xFF) == 0x89 && data[1]=='P' && data[2]=='N' && data[3]=='G') return true;
        // GIF
        if (data[0]=='G' && data[1]=='I' && data[2]=='F') return true;
        // WEBP
        if (data[0]=='R' && data[1]=='I' && data[2]=='F' && data[3]=='F'
                && data[8]=='W' && data[9]=='E' && data[10]=='B' && data[11]=='P') return true;
        return false;
    }

    private String sniffContentType(byte[] data, String fallback) {
        if (data != null && data.length >= 12) {
            if ((data[0] & 0xFF) == 0xFF && (data[1] & 0xFF) == 0xD8) return "image/jpeg";
            if (data[0]==(byte)0x89 && data[1]=='P' && data[2]=='N' && data[3]=='G') return "image/png";
            if (data[0]=='G' && data[1]=='I' && data[2]=='F') return "image/gif";
            if (data[0]=='R' && data[1]=='I' && data[2]=='F' && data[3]=='F'
                    && data[8]=='W' && data[9]=='E' && data[10]=='B' && data[11]=='P') return "image/webp";
        }
        return (fallback != null) ? fallback : "application/octet-stream";
    }

    private String inferBrand(String urlOrPayload) {
        String s = urlOrPayload.toLowerCase(Locale.ROOT);
        if (s.contains("life4cut") || s.contains("인생네컷")) return "인생네컷";
        if (s.contains("harufilm") || s.contains("하루필름")) return "하루필름";
        if (s.contains("photoism")) return "포토이즘";
        if (s.contains("signature")) return "포토시그니쳐";
        if (s.contains("twin")) return "트윈포토";
        if (s.contains("photogray") || s.contains("pgshort") || s.contains("pg-qr-resource")) return "포토그레이";
        return "기타";
    }

    private static class HtmlExtracted {
        String imageUrl;
        String thumbnailUrl;
        String videoUrl;
        String nextGetUrl;
    }

    private static class AssetPair {
        final String imageUrl, thumbnailUrl, videoUrl;
        final LocalDateTime takenAt;
        AssetPair(String i, String t, String v, LocalDateTime ta) {
            this.imageUrl = i;
            this.thumbnailUrl = t;
            this.videoUrl = v;
            this.takenAt = ta;
        }
    }

    /**
     * 사진 상세/즐겨찾기 권한 체크
     * - 1) 사진 소유자
     * - 2) 공유 앨범(ACCEPTED) 멤버이면서, 해당 앨범에 이 사진이 포함된 경우
     */
    private boolean hasPhotoAccess(Long userId, Photo photo) {
        // 1) 본인 사진
        if (photo.getUserId() != null && photo.getUserId().equals(userId)) {
            return true;
        }

        // 2) 공유받은 앨범 중 이 사진을 포함하는 앨범이 있는지 확인
        List<AlbumShare> shares = albumShareRepository
                .findByUserIdAndStatusAndActiveTrue(userId, AlbumShare.Status.ACCEPTED);

        for (AlbumShare share : shares) {
            if (share.getAlbum() == null || share.getAlbum().getPhotos() == null) {
                continue;
            }

            boolean contains = share.getAlbum().getPhotos().stream()
                    .filter(p -> !Boolean.TRUE.equals(p.getDeleted()))
                    .anyMatch(p -> Objects.equals(p.getId(), photo.getId()));

            if (contains) {
                return true;
            }
        }

        return false;
    }
}
