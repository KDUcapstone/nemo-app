// com.nemo.backend.domain.photo.service.PhotoServiceImpl
package com.nemo.backend.domain.photo.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.domain.photo.repository.PhotoRepository;
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
import java.util.HexFormat;
import java.util.Iterator;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static com.nemo.backend.domain.photo.service.S3PhotoStorage.StorageException;

@Slf4j
@Service
@Transactional
public class PhotoServiceImpl implements PhotoService {

    private static final int CONNECT_TIMEOUT_MS = 5000;
    private static final int READ_TIMEOUT_MS    = 10000;
    private static final int MAX_REDIRECTS      = 5;
    private static final int MAX_HTML_FOLLOW    = 2;   // 필요 시 4까지 늘릴 수 있음
    private static final long MAX_BYTES         = 50L * 1024 * 1024;
    private static final String USER_AGENT      = "Mozilla/5.0 Nemo/1.0";
    private static final int MIN_IMAGE_BYTES    = 5 * 1024;

    private static final ObjectMapper JSON = new ObjectMapper();

    private final PhotoRepository photoRepository;
    private final PhotoStorage storage;
    private final String publicBaseUrl;

    public PhotoServiceImpl(PhotoRepository photoRepository,
                            PhotoStorage storage,
                            @Value("${app.public-base-url:http://localhost:8080}") String publicBaseUrl) {
        this.photoRepository = photoRepository;
        this.storage = storage;
        this.publicBaseUrl = publicBaseUrl.replaceAll("/+$", "");
    }

    private String toPublicUrl(String key) {
        return String.format("%s/files/%s", publicBaseUrl, key);
    }

    // ========================================================
    // 1) QR/갤러리 혼합 업로드 (기존 로직 유지 + location/memo 저장)
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

        // 🔍 QR / 이미지 인입 로그
        log.info("[QR][uploadHybrid] userId={}, brand={}, qr='{}', hasImage={}, imageName={}",
                userId,
                brand,
                qrUrlOrPayload,
                (image != null && !image.isEmpty()),
                (image != null ? image.getOriginalFilename() : null)
        );

        if ((qrUrlOrPayload == null || qrUrlOrPayload.isBlank()) && (image == null || image.isEmpty())) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "image 또는 qrUrl/qrCode 중 하나는 필수입니다.");
        }

        // 중복 QR 차단: URL/QR 문자열이 있을 때만
        if (qrUrlOrPayload != null && !qrUrlOrPayload.isBlank()) {
            String qrHash = sha256Hex(qrUrlOrPayload);
            photoRepository.findByQrHash(qrHash)
                    .ifPresent(p -> { throw new ApiException(ErrorCode.CONFLICT, "이미 업로드된 QR입니다."); });
        }

        String storedImage;
        String storedThumb;
        String storedVideo = null;

        if (image != null && !image.isEmpty()) {
            try {
                String key = storage.store(image);                 // 여기서 INVALID_ARGUMENT 던질 수 있음
                String url = toPublicUrl(key);
                storedImage = url;
                storedThumb = url;
            } catch (ApiException ae) {
                // 파일 바이트가 HTML/JSON → url 폴백
                if (ae.getErrorCode() == ErrorCode.INVALID_ARGUMENT && looksLikeUrl(qrUrlOrPayload)) {
                    AssetPair ap = fetchAssetsFromQrPayload(qrUrlOrPayload);
                    storedImage = ap.imageUrl;
                    storedThumb = ap.thumbnailUrl != null ? ap.thumbnailUrl : ap.imageUrl;
                    storedVideo = ap.videoUrl;
                    if (takenAt == null) takenAt = ap.takenAt;
                } else {
                    // 그대로 전달 (글로벌 핸들러가 적절한 상태코드로 응답)
                    throw ae;
                }
            } catch (Exception e) {
                // 진짜 저장 실패만 500/502 계열로
                throw new ApiException(ErrorCode.STORAGE_FAILED, "파일 저장 실패: " + e.getMessage(), e);
            }
        } else {
            // URL 경로 (QR 문자열만 있는 케이스)
            if (!looksLikeUrl(qrUrlOrPayload)) {
                throw new InvalidQrException("지원하지 않는 QR/URL 포맷입니다.");
            }
            AssetPair ap = fetchAssetsFromQrPayload(qrUrlOrPayload);
            storedImage = ap.imageUrl;
            storedThumb = ap.thumbnailUrl != null ? ap.thumbnailUrl : ap.imageUrl;
            storedVideo = ap.videoUrl;
            if (takenAt == null) takenAt = ap.takenAt;
        }

        if (brand == null || brand.isBlank()) {
            brand = (qrUrlOrPayload != null) ? inferBrand(qrUrlOrPayload) : "기타";
        }
        if (takenAt == null) takenAt = LocalDateTime.now();

        String qrHash = (qrUrlOrPayload != null && !qrUrlOrPayload.isBlank()) ? sha256Hex(qrUrlOrPayload) : null;

        Photo photo = new Photo(userId, null, storedImage, storedThumb, storedVideo, qrHash, brand, takenAt, null);
        // ✅ 위치명 / 메모 저장 (엔티티에 필드가 있어야 함)
        photo.setLocationName(location);
        photo.setMemo(memo);

        Photo saved = photoRepository.save(photo);
        return new PhotoResponseDto(saved);
    }

    // ========================================================
    // 2) 사진 목록 조회 (favorite 필터 지원)
    // ========================================================
    @Override
    @Transactional(readOnly = true)
    public Page<PhotoResponseDto> list(Long userId, Pageable pageable, Boolean favorite) {
        Page<Photo> page;
        if (Boolean.TRUE.equals(favorite)) {
            page = photoRepository.findByUserIdAndDeletedIsFalseAndFavoriteTrueOrderByCreatedAtDesc(userId, pageable);
        } else {
            page = photoRepository.findByUserIdAndDeletedIsFalseOrderByCreatedAtDesc(userId, pageable);
        }
        return page.map(PhotoResponseDto::new);
    }

    // 혹시 인터페이스에 옛날 시그니처가 남아있다면, 이렇게 위임해도 됨.
    @Transactional(readOnly = true)
    public Page<PhotoResponseDto> list(Long userId, Pageable pageable) {
        return list(userId, pageable, null);
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
        if (!photo.getUserId().equals(userId)) {
            throw new ApiException(ErrorCode.UNAUTHORIZED, "해당 사진에 접근할 권한이 없습니다.");
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
            photo.setLocationName(location);
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
        if (!photo.getUserId().equals(userId)) {
            throw new ApiException(ErrorCode.UNAUTHORIZED, "즐겨찾기 권한이 없습니다.");
        }

        boolean current = Boolean.TRUE.equals(photo.getFavorite());
        boolean next = !current;
        photo.setFavorite(next);
        photoRepository.save(photo);
        return next;
    }

    // ===================== 네트워크/QR 파싱 (기존 코드 그대로) =====================

    /**
     * QR 에서 얻은 URL(또는 payload)을 시작점으로,
     * 리다이렉트/HTML/JSON/첨부파일을 따라가면서 최종 이미지/영상 파일을 우리 스토리지에 저장한다.
     * - 인생네컷(life4cut) 전용 webQr → webQrJson 처리 포함
     */
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
                HttpURLConnection conn = open(current, "GET", null, startUrl);
                int code = conn.getResponseCode();

                // 3xx 리다이렉트 처리
                if (code / 100 == 3) {
                    String location = conn.getHeaderField("Location");
                    if (location == null || location.isBlank()) {
                        throw new IOException("Redirect without Location");
                    }
                    current = new URL(url, location).toString();
                    continue;
                }

                // 2xx 가 아니면 실패
                if (code < 200 || code >= 300) {
                    throw new IOException("HTTP " + code + " from " + current);
                }

                String contentType = safeLower(conn.getContentType());
                String cd = conn.getHeaderField("Content-Disposition");
                boolean isAttachment = cd != null && cd.toLowerCase(Locale.ROOT).contains("attachment");

                // ================================
                // 🔥 life4cut 전용: webQr → direct S3 URL 강제 시도
                // ================================
                String specialNext = resolveLife4cutNextUrl(url);
                if (specialNext != null && !isSamePage(specialNext, current)) {
                    log.info("[QR][life4cut][forceJump] {} -> {}", current, specialNext);
                    current = specialNext;
                    continue;
                }

                // ================================
                // 1) 이미지/영상 혹은 첨부 응답 → 바로 저장
                // ================================
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
                            String key = storage.storeBytes(
                                    data,
                                    filenameFromHeadersOrUrl(url, cd, ct),
                                    ct
                            );
                            String publicUrl = toPublicUrl(key);
                            if (foundVideo == null) foundVideo = publicUrl;
                        }
                    } catch (Exception e) {
                        throw new StorageException("파일 저장 실패", e);
                    }

                    // 이미지/영상까지 왔으면 루프 종료
                    break;
                }

                // ================================
                // 2) 일반 HTML → HTML 파서로 링크 추적
                // ================================
                if (contentType != null && contentType.startsWith("text/html")) {
                    if (htmlFollow >= MAX_HTML_FOLLOW) break;

                    String html = readAll(conn.getInputStream());
                    HtmlExtracted he = extractFromHtml(html, current);

                    if (he.imageUrl != null && !isSamePage(he.imageUrl, current)) {
                        current = new URL(url, he.imageUrl).toString();
                        htmlFollow++;
                        continue;
                    }
                    // 더 이상 따라갈 링크가 없으면 종료
                    break;
                }

                // 그 밖의 컨텐츠 타입은 더 이상 진행하지 않고 중단
                break;
            }

            if (foundImage == null && foundVideo == null) {
                throw new IOException("이미지/영상 URL을 찾지 못했습니다.");
            }
            if (foundThumb == null) foundThumb = foundImage;

            return new AssetPair(foundImage, foundThumb, foundVideo, null);
        } catch (StorageException e) {
            // 저장 실패는 그대로 올림
            throw e;
        } catch (Exception e) {
            // 나머지는 UPSTREAM_FAILED 로 래핑
            throw new ApiException(ErrorCode.UPSTREAM_FAILED,
                    "원격 자산 추출 실패: " + e.getMessage(), e);
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
}
