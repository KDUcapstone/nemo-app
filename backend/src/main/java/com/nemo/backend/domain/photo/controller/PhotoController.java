// backend/src/main/java/com/nemo/backend/domain/photo/controller/PhotoController.java
package com.nemo.backend.domain.photo.controller;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nemo.backend.domain.auth.util.AuthExtractor;
import com.nemo.backend.domain.photo.dto.PhotoListItemDto;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.dto.PhotoUploadRequest;
import com.nemo.backend.domain.photo.service.PhotoService;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import com.nemo.backend.web.PageMetaDto;
import com.nemo.backend.web.PagedResponse;
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

    private static final ObjectMapper JSON = new ObjectMapper();

    // ========================================================
    // 1) QR 기반 사진 업로드  (POST /api/photos)
    // ========================================================
    @Operation(
            summary = "QR 사진 업로드",
            description = "포토부스 QR 기반으로 사진을 업로드합니다.",
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
            @RequestPart(value = "image", required = false) MultipartFile image,
            @RequestParam(value = "qrUrl", required = false) String qrUrl,
            @RequestParam(value = "qrCode", required = false) String qrCode,
            @RequestParam(value = "takenAt", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime takenAt,
            @RequestParam(value = "location", required = false) String location,
            @RequestParam(value = "brand", required = false) String brand,
            @RequestParam(value = "tagList", required = false) String tagListJson,
            @RequestParam(value = "friendIdList", required = false) String friendIdListJson,
            @RequestParam(value = "memo", required = false) String memo
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        String effectiveQr = (qrUrl != null && !qrUrl.isBlank()) ? qrUrl : qrCode;

        if ((effectiveQr == null || effectiveQr.isBlank())
                && (image == null || image.isEmpty())) {
            throw new ApiException(
                    ErrorCode.INVALID_ARGUMENT,
                    "image 또는 qrCode/qrUrl 중 하나는 필수입니다. (IMAGE_OR_QR_REQUIRED)"
            );
        }

        PhotoUploadRequest req = new PhotoUploadRequest(
                image,
                effectiveQr,
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
        var pageDto = photoService.list(userId, pageable, favorite);
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
                Collections.emptyList(),     // tagList – 아직 별도 테이블 미구현
                Collections.emptyList(),     // friendList – 아직 미구현
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
            @RequestBody PhotoDetailsUpdateRequest body
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
                Collections.emptyList(), // friendList 실제 매핑은 추후 구현
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

    // ========================================================
    // 내부 DTO & 유틸
    // ========================================================
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
}
