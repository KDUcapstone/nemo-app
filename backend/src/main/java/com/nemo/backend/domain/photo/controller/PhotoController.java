// backend/src/main/java/com/nemo/backend/domain/photo/controller/PhotoController.java
package com.nemo.backend.domain.photo.controller;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nemo.backend.domain.auth.util.AuthExtractor;
import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.entity.AlbumShare;
import com.nemo.backend.domain.album.repository.AlbumRepository;
import com.nemo.backend.domain.album.repository.AlbumShareRepository;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.domain.photo.repository.PhotoRepository;
import com.nemo.backend.domain.photo.dto.PhotoListItemDto;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.dto.PhotoUploadRequest;
import com.nemo.backend.domain.photo.dto.SelectedPhotosDownloadUrlsResponse;
import com.nemo.backend.domain.photo.service.PhotoService;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import com.nemo.backend.web.PageMetaDto;
import com.nemo.backend.web.PagedResponse;
import com.nemo.backend.domain.file.S3FileService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.parameters.RequestBody;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.core.io.ByteArrayResource;

import java.net.URI; // ✅ 추가
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.*;

@SecurityRequirement(name = "BearerAuth")
@RestController
@RequestMapping(
        value = "/api/photos",
        produces = "application/json; charset=UTF-8"
)
@RequiredArgsConstructor
public class PhotoController {

    private final PhotoService photoService;
    private final AuthExtractor authExtractor;
    private final UserRepository userRepository;
    private final PhotoRepository photoRepository;
    private final AlbumRepository albumRepository;
    private final AlbumShareRepository albumShareRepository;
    private final S3FileService fileService;   // ✅ 추가

    @org.springframework.beans.factory.annotation.Value("${app.public-base-url:http://localhost:8080}")
    private String publicBaseUrl;              // ✅ 추가

    private static final ObjectMapper JSON = new ObjectMapper();

    // ========================================================
    // 0) QR 임시 등록 (미리보기용)  (POST /api/photos/qr-import)
    // ========================================================
    @Operation(
            summary = "QR 임시 등록 (미리보기)",
            description = "포토부스 QR 문자열을 받아 원본 이미지를 조회·저장하고 미리보기 정보를 반환합니다."
    )
    @PostMapping(
            value = "/qr-import",
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public ResponseEntity<QrImportResponse> qrImport(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @org.springframework.web.bind.annotation.RequestBody QrImportRequest body
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        if (body == null || body.qrCode() == null || body.qrCode().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "qrCode는 필수입니다.");
        }

        PhotoResponseDto dto = photoService.uploadHybrid(
                userId,
                body.qrCode(),
                null,
                null,
                null,
                null,
                null,
                null,
                null
        );

        String isoTakenAt = (dto.getTakenAt() != null)
                ? dto.getTakenAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                : null;

        QrImportResponse resp = new QrImportResponse(
                dto.getId(),
                dto.getImageUrl(),
                isoTakenAt,
                dto.getLocation(),
                dto.getBrand(),
                "DRAFT"
        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .contentType(MediaType.APPLICATION_JSON)
                .body(resp);
    }

    // ========================================================
    // 1) QR 기반 사진 업로드  (POST /api/photos)
    // ========================================================
    @Operation(
            summary = "QR 사진 업로드",
            description = "포토부스 QR 기반으로 사진을 업로드합니다. qrCode와 image는 필수입니다.",
            requestBody = @RequestBody(
                    content = @Content(mediaType = MediaType.MULTIPART_FORM_DATA_VALUE)
            )
    )
    @PostMapping(
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public ResponseEntity<PhotoUploadResponse> uploadByQr(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @RequestPart(value = "image", required = true) MultipartFile image,
            @RequestParam(value = "qrCode", required = true) String qrCode,
            @RequestParam(value = "takenAt", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime takenAt,
            @RequestParam(value = "location", required = false) String location,
            @RequestParam(value = "brand", required = false) String brand,
            @RequestParam(value = "tagList", required = false) String tagListJson,
            @RequestParam(value = "friendIdList", required = false) String friendIdListJson,
            @RequestParam(value = "memo", required = false) String memo
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        if (qrCode == null || qrCode.isBlank()) {
            throw new ApiException(
                    ErrorCode.INVALID_ARGUMENT,
                    "qrCode는 필수입니다. (QRCODE_REQUIRED)"
            );
        }

        if (image == null || image.isEmpty()) {
            throw new ApiException(
                    ErrorCode.INVALID_ARGUMENT,
                    "image는 필수입니다. (IMAGE_REQUIRED)"
            );
        }

        PhotoUploadRequest req = new PhotoUploadRequest(
                image,
                qrCode,
                qrCode,
                (takenAt != null) ? takenAt.toString() : null,
                location,
                brand,
                memo
        );

        PhotoResponseDto dto = photoService.uploadHybrid(
                userId,
                req.qrUrl(),
                req.image(),
                brand,
                location,
                takenAt,
                tagListJson,
                friendIdListJson,
                memo
        );

        String isoTakenAt = (dto.getTakenAt() != null)
                ? dto.getTakenAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                : (takenAt != null ? takenAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME) : null);

        List<String> tagList = parseStringArray(tagListJson);
        List<FriendDto> friendList = parseFriendList(friendIdListJson);

        PhotoUploadResponse resp = new PhotoUploadResponse(
                dto.getId(),
                dto.getImageUrl(),
                isoTakenAt,
                dto.getLocation(),
                dto.getBrand(),
                tagList,
                friendList,
                dto.getMemo() != null ? dto.getMemo() : ""
        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .contentType(MediaType.APPLICATION_JSON)
                .body(resp);
    }

    // ========================================================
    // 2) 갤러리 사진 업로드  (POST /api/photos/gallery)
    // ========================================================
    @Operation(
            summary = "갤러리 사진 업로드",
            description = "휴대폰 갤러리에서 선택한 사진을 업로드합니다.",
            requestBody = @RequestBody(
                    content = @Content(mediaType = MediaType.MULTIPART_FORM_DATA_VALUE)
            )
    )
    @PostMapping(
            value = "/gallery",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public ResponseEntity<PhotoUploadResponse> uploadFromGallery(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @RequestPart(value = "image", required = true) MultipartFile image,
            @RequestParam(value = "takenAt", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime takenAt,
            @RequestParam(value = "location", required = false) String location,
            @RequestParam(value = "brand", required = false) String brand,
            @RequestParam(value = "tagList", required = false) String tagListJson,
            @RequestParam(value = "friendIdList", required = false) String friendIdListJson,
            @RequestParam(value = "memo", required = false) String memo
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        if (image == null || image.isEmpty()) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "사진 파일은 필수입니다. (IMAGE_REQUIRED)");
        }

        PhotoUploadRequest req = new PhotoUploadRequest(
                image,
                null,
                null,
                (takenAt != null) ? takenAt.toString() : null,
                location,
                brand,
                memo
        );

        PhotoResponseDto dto = photoService.uploadHybrid(
                userId,
                null,
                req.image(),
                brand,
                location,
                takenAt,
                tagListJson,
                friendIdListJson,
                memo
        );

        String isoTakenAt = (dto.getTakenAt() != null)
                ? dto.getTakenAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                : (takenAt != null ? takenAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME) : null);

        List<String> tagList = parseStringArray(tagListJson);
        List<FriendDto> friendList = parseFriendList(friendIdListJson);

        PhotoUploadResponse resp = new PhotoUploadResponse(
                dto.getId(),
                dto.getImageUrl(),
                isoTakenAt,
                dto.getLocation(),
                dto.getBrand(),
                tagList,
                friendList,
                dto.getMemo() != null ? dto.getMemo() : ""
        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .contentType(MediaType.APPLICATION_JSON)
                .body(resp);
    }

    // ========================================================
    // 3) 사진 목록 조회  (GET /api/photos)
    // ========================================================
    @GetMapping(produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<PagedResponse<PhotoListItemDto>> list(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @RequestParam(value = "favorite", required = false) Boolean favorite,
            @RequestParam(value = "brand", required = false) String brand,
            @RequestParam(value = "tag", required = false) String tag,
            @RequestParam(value = "sort", required = false, defaultValue = "takenAt,desc") String sortBy,
            @RequestParam(value = "page", required = false, defaultValue = "0") Integer page,
            @RequestParam(value = "size", required = false, defaultValue = "20") Integer size
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        Sort sort = Sort.by(Sort.Direction.DESC, "takenAt");
        if (sortBy != null && !sortBy.isBlank()) {
            String[] parts = sortBy.split(",");
            String field = parts[0].trim();
            Sort.Direction dir = (parts.length > 1 && "asc".equalsIgnoreCase(parts[1].trim()))
                    ? Sort.Direction.ASC : Sort.Direction.DESC;

            switch (field) {
                case "takenAt" -> sort = Sort.by(dir, "takenAt");
                case "createdAt" -> sort = Sort.by(dir, "createdAt");
                case "photoId", "id" -> sort = Sort.by(dir, "id");
                default -> sort = Sort.by(Sort.Direction.DESC, "takenAt");
            }
        }

        Pageable pageable = PageRequest.of(page, size, sort);

        var pageDto = photoService.list(userId, pageable, favorite, brand, tag);
        DateTimeFormatter ISO = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

        List<PhotoListItemDto> items = pageDto.map(p -> PhotoListItemDto.builder()
                .photoId(p.getId())
                .imageUrl(p.getImageUrl())
                .takenAt(p.getTakenAt() != null ? p.getTakenAt().format(ISO) : null)
                .location(p.getLocation())
                .brand(p.getBrand())
                .isFavorite(p.isFavorite())
                .build()
        ).getContent();

        PageMetaDto meta = new PageMetaDto(
                pageDto.getSize(),
                pageDto.getTotalElements(),
                pageDto.getTotalPages(),
                pageDto.getNumber()
        );

        return ResponseEntity.ok(new PagedResponse<>(items, meta));
    }

    // ========================================================
    // 4) 사진 상세 조회  (GET /api/photos/{photoId})
    // ========================================================
    @GetMapping(value = "/{photoId}",
            produces = "application/json; charset=UTF-8")
    public ResponseEntity<PhotoDetailResponse> getDetail(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long photoId
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        PhotoResponseDto dto = photoService.getDetail(userId, photoId);

        User owner = userRepository.findById(dto.getUserId())
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_ARGUMENT, "소유자를 찾을 수 없습니다."));

        PhotoDetailResponse resp = new PhotoDetailResponse(
                dto.getId(),
                dto.getImageUrl(),
                dto.getTakenAt() != null
                        ? dto.getTakenAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                        : null,
                dto.getLocation(),
                dto.getBrand(),
                Collections.emptyList(),
                Collections.emptyList(),
                dto.getMemo() != null ? dto.getMemo() : "",
                dto.isFavorite(),
                new OwnerDto(
                        owner.getId(),
                        owner.getNickname() != null ? owner.getNickname() : "",
                        owner.getProfileImageUrl() != null ? owner.getProfileImageUrl() : ""
                )
        );

        return ResponseEntity.ok(resp);
    }

    // ========================================================
    // 5) 사진 상세정보 수정  (PATCH /api/photos/{photoId}/details)
    // ========================================================
    @PatchMapping(value = "/{photoId}/details", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<PhotoDetailResponse> updateDetails(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long photoId,
            @org.springframework.web.bind.annotation.RequestBody PhotoDetailsUpdateRequest body
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        LocalDateTime takenAt = null;
        if (body.takenAt() != null && !body.takenAt().isBlank()) {
            try {
                takenAt = LocalDateTime.parse(body.takenAt(), DateTimeFormatter.ISO_LOCAL_DATE_TIME);
            } catch (DateTimeParseException e) {
                throw new ApiException(
                        ErrorCode.INVALID_ARGUMENT,
                        "촬영 날짜 형식이 잘못되었습니다. ISO 8601 형식을 사용해주세요."
                );
            }
        }

        PhotoResponseDto dto = photoService.updateDetails(
                userId,
                photoId,
                takenAt,
                body.location(),
                body.brand(),
                body.memo()
        );

        User owner = userRepository.findById(dto.getUserId())
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_ARGUMENT, "소유자를 찾을 수 없습니다."));

        PhotoDetailResponse resp = new PhotoDetailResponse(
                dto.getId(),
                dto.getImageUrl(),
                dto.getTakenAt() != null
                        ? dto.getTakenAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                        : null,
                dto.getLocation(),
                dto.getBrand(),
                body.tagList() != null ? body.tagList() : Collections.emptyList(),
                Collections.emptyList(),
                dto.getMemo() != null ? dto.getMemo() : "",
                dto.isFavorite(),
                new OwnerDto(
                        owner.getId(),
                        owner.getNickname() != null ? owner.getNickname() : "",
                        owner.getProfileImageUrl() != null ? owner.getProfileImageUrl() : ""
                )
        );

        return ResponseEntity.ok(resp);
    }

    // ========================================================
    // 6) 사진 즐겨찾기 토글  (POST /api/photos/{photoId}/favorite)
    // ========================================================
    @PostMapping("/{photoId}/favorite")
    public ResponseEntity<FavoriteToggleResponse> toggleFavorite(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long photoId
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);
        boolean nowFavorite = photoService.toggleFavorite(userId, photoId);

        String message = nowFavorite ? "즐겨찾기 설정 완료" : "즐겨찾기 해제 완료";
        FavoriteToggleResponse resp = new FavoriteToggleResponse(photoId, nowFavorite, message);
        return ResponseEntity.ok(resp);
    }

    // ========================================================
    // 7) 사진 삭제  (DELETE /api/photos/{id})
    // ========================================================
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> delete(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable("id") Long photoId) {

        Long userId = authExtractor.extractUserId(authorizationHeader);
        photoService.delete(userId, photoId);

        Map<String, Object> body = new HashMap<>();
        body.put("photoId", photoId);
        body.put("message", "사진이 성공적으로 삭제되었습니다.");
        return ResponseEntity.ok(body);
    }

    // 8) 단일 사진 다운로드  (GET /api/photos/{photoId}/download)
    //     - 사진 소유자이거나
    //     - 사진이 포함된 앨범의 멤버(OWNER / CO_OWNER / EDITOR / VIEWER)인 경우만 허용
    @GetMapping(value = "/{photoId}/download", produces = MediaType.ALL_VALUE)
    public ResponseEntity<?> downloadPhoto(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long photoId
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        Photo photo = photoRepository.findByIdAndDeletedIsFalse(photoId)
                .orElseThrow(() -> new ApiException(
                        ErrorCode.PHOTO_NOT_FOUND,
                        "해당 사진을 찾을 수 없습니다.")
                );

        if (!canDownloadPhoto(userId, photo)) {
            throw new ApiException(
                    ErrorCode.FORBIDDEN,
                    "해당 사진을 다운로드할 권한이 없습니다."
            );
        }

        String imageUrl = photo.getImageUrl();
        if (imageUrl == null || imageUrl.isBlank()) {
            throw new ApiException(
                    ErrorCode.PHOTO_NOT_FOUND,
                    "해당 사진의 원본 파일을 찾을 수 없습니다."
            );
        }

        // ✅ 우리 서비스가 관리하는 /files/{key} 형태면 S3에서 직접 200으로 내려줌
        String key = extractStorageKeyFromUrl(imageUrl);
        if (key != null) {
            S3FileService.FileObject obj = fileService.get(key);
            byte[] bytes = obj.bytes();
            String ct = (obj.contentType() == null || obj.contentType().isBlank())
                    ? "application/octet-stream"
                    : obj.contentType();

            String filename = key.substring(key.lastIndexOf('/') + 1);
            String encoded = URLEncoder.encode(filename, StandardCharsets.UTF_8)
                    .replace("+", "%20");

            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(ct))
                    .contentLength(bytes.length)
                    .header(HttpHeaders.CONTENT_DISPOSITION,
                            "attachment; filename*=UTF-8''" + encoded)
                    .body(new ByteArrayResource(bytes));
        }

        // ⚠️ 외부 CDN(URL이 우리 publicBaseUrl이 아닌 경우)은 여전히 302로 우회
        HttpHeaders headers = new HttpHeaders();
        headers.setLocation(URI.create(imageUrl));
        return new ResponseEntity<>(headers, HttpStatus.FOUND);
    }

    // ========================================================
    // 9) 선택 사진 다운로드 URL 목록 조회 (POST /api/photos/download-urls)
    // ========================================================
    @PostMapping("/download-urls")
    public ResponseEntity<SelectedPhotosDownloadUrlsResponse> getDownloadUrls(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @org.springframework.web.bind.annotation.RequestBody SelectedPhotosDownloadRequest body
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        if (body == null || body.photoIdList() == null || body.photoIdList().isEmpty()) {
            // ✅ 명세: INVALID_REQUEST
            throw new ApiException(
                    ErrorCode.INVALID_REQUEST,
                    "photoIdList는 비어 있을 수 없습니다."
            );
        }

        SelectedPhotosDownloadUrlsResponse resp =
                photoService.getDownloadUrls(userId, body.photoIdList());

        return ResponseEntity.ok(resp);
    }


    // ========================================================
    // 내부 DTO & 유틸
    // ========================================================
    public static record QrImportRequest(
            String qrCode
    ) {}

    public static record QrImportResponse(
            long photoId,
            String imageUrl,
            String takenAt,
            String location,
            String brand,
            String status
    ) {}

    public static record PhotoUploadResponse(
            long photoId,
            String imageUrl,
            String takenAt,
            String location,
            String brand,
            List<String> tagList,
            List<FriendDto> friendList,
            String memo
    ) {}

    public static record FriendDto(
            long userId,
            String nickname
    ) {}

    public static record OwnerDto(
            long userId,
            String nickname,
            String profileImageUrl
    ) {}

    public static record PhotoDetailResponse(
            long photoId,
            String imageUrl,
            String takenAt,
            String location,
            String brand,
            List<String> tagList,
            List<FriendDto> friendList,
            String memo,
            boolean isFavorite,
            OwnerDto owner
    ) {}

    public static record FavoriteToggleResponse(
            long photoId,
            boolean isFavorite,
            String message
    ) {}

    public static record PhotoDetailsUpdateRequest(
            String takenAt,
            String location,
            String brand,
            List<String> tagList,
            List<Long> friendIdList,
            String memo
    ) {}

    public static record SelectedPhotosDownloadRequest(
            List<Long> photoIdList
    ) {}

    // === 권한/앨범 유틸 ===

    /**
     * 단일 사진 다운로드 권한 체크
     * - 사진 소유자이거나
     * - 사진이 포함된 앨범의 멤버(OWNER / CO_OWNER / EDITOR / VIEWER)이면 true
     */
    private boolean canDownloadPhoto(Long userId, Photo photo) {
        if (photo.getUserId() != null && photo.getUserId().equals(userId)) {
            return true;
        }
        Set<Long> accessiblePhotoIds = getAlbumPhotoIdsUserCanAccess(userId);
        return accessiblePhotoIds.contains(photo.getId());
    }

    /**
     * 현재 사용자(userId)가 멤버로 접근 가능한 모든 앨범에 포함된 사진 ID 집합
     * - 내가 소유한 앨범
     * - 공유받아서 수락한 앨범(Status.ACCEPTED, active=true)
     */
    private Set<Long> getAlbumPhotoIdsUserCanAccess(Long userId) {
        Set<Long> ids = new HashSet<>();

        // 내가 소유한 앨범
        List<Album> myAlbums = albumRepository.findByUserId(userId);
        for (Album album : myAlbums) {
            if (album.getPhotos() == null) continue;
            album.getPhotos().stream()
                    .filter(p -> Boolean.FALSE.equals(p.getDeleted()))
                    .forEach(p -> ids.add(p.getId()));
        }

        // 공유받은 앨범 (ACCEPTED + active)
        List<AlbumShare> shares =
                albumShareRepository.findByUserIdAndStatusAndActiveTrue(userId, AlbumShare.Status.ACCEPTED);
        for (AlbumShare share : shares) {
            Album album = share.getAlbum();
            if (album == null || album.getPhotos() == null) continue;
            album.getPhotos().stream()
                    .filter(p -> Boolean.FALSE.equals(p.getDeleted()))
                    .forEach(p -> ids.add(p.getId()));
        }

        return ids;
    }

    // === 기존 JSON 파서 유틸 ===

    private List<String> parseStringArray(String jsonArray) {
        if (jsonArray == null || jsonArray.isBlank()) return Collections.emptyList();
        try {
            return JSON.readValue(jsonArray, new TypeReference<List<String>>() {});
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }

    private List<FriendDto> parseFriendList(String friendIdListJson) {
        if (friendIdListJson == null || friendIdListJson.isBlank()) return Collections.emptyList();
        try {
            List<Long> ids = JSON.readValue(friendIdListJson, new TypeReference<List<Long>>() {});
            List<FriendDto> result = new ArrayList<>();
            for (Long id : ids) {
                result.add(new FriendDto(id, ""));
            }
            return result;
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }

    /**
     * publicBaseUrl + "/files/{key}" 형태의 URL에서 S3 key만 추출
     * 예: http://localhost:8080/files/albums/2025-11-27/xxx.webp
     *  -> albums/2025-11-27/xxx.webp
     */
    private String extractStorageKeyFromUrl(String url) {
        if (url == null || url.isBlank()) return null;

        String base = publicBaseUrl;
        if (base == null || base.isBlank()) return null;

        // publicBaseUrl 뒤의 여분 슬래시 제거
        base = base.replaceAll("/+$", "");

        if (!url.startsWith(base)) {
            // 우리 서비스에서 관리하는 URL이 아니면 S3 조회 대상 아님
            return null;
        }

        String path = url.substring(base.length()); // "/files/...."
        if (!path.startsWith("/files/")) {
            return null;
        }

        return path.substring("/files/".length());  // "albums/2025-11-27/xxx.webp"
    }

}
