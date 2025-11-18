package com.nemo.backend.domain.photo.controller;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nemo.backend.domain.auth.util.AuthExtractor;          // 🔐 공통 인증 유틸
import com.nemo.backend.domain.photo.dto.PhotoListItemDto;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.dto.PhotoUploadRequest;
import com.nemo.backend.domain.photo.service.PhotoService;
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
import java.util.*;

@SecurityRequirement(name = "BearerAuth")
@RestController
@RequestMapping("/api/photos")
@RequiredArgsConstructor
public class PhotoController {

    private final PhotoService photoService;
    private final AuthExtractor authExtractor;

    private static final ObjectMapper JSON = new ObjectMapper();

    // ========================================================
    // 1) QR 기반 사진 업로드  (POST /api/photos)
    //    - 명세 기준: qrCode + image + 메타데이터
    //    - 구현: qrCode / image 둘 중 최소 하나는 필수
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

            // 명세서 기준 필드명
            @RequestPart(value = "qrCode", required = false) String qrCode,
            @RequestPart(value = "image", required = false) MultipartFile image,
            @RequestPart(value = "takenAt", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime takenAt,
            @RequestPart(value = "location", required = false) String location,
            @RequestPart(value = "brand", required = false) String brand,
            @RequestPart(value = "tagList", required = false) String tagListJson,
            @RequestPart(value = "friendIdList", required = false) String friendIdListJson,
            @RequestPart(value = "memo", required = false) String memo
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        // ✅ 최소 조건 체크: qrCode 또는 image 둘 중 하나는 있어야 함
        if ((qrCode == null || qrCode.isBlank())
                && (image == null || image.isEmpty())) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "image 또는 qrCode 중 하나는 필수입니다. (IMAGE_REQUIRED)");
        }

        // 하나의 DTO로 합성(필요하면 서비스에서 더 세부 분기)
        PhotoUploadRequest req = new PhotoUploadRequest(
                image,
                qrCode,    // qrUrlOrPayload 용도로 사용
                qrCode,
                (takenAt != null) ? takenAt.toString() : null,
                location,
                brand,
                memo
        );

        PhotoResponseDto dto = photoService.uploadHybrid(
                userId,
                req.qrUrl(),      // qrUrlOrPayload
                req.image(),
                brand,
                location,
                takenAt,
                tagListJson,
                friendIdListJson,
                memo
        );

        // 응답 DTO 구성 (명세서 기준)
        String isoTakenAt = (dto.getTakenAt() != null)
                ? dto.getTakenAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                : (takenAt != null ? takenAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME) : null);

        List<String> tagList = parseStringArray(tagListJson);
        List<FriendDto> friendList = parseFriendList(friendIdListJson);

        PhotoUploadResponse resp = new PhotoUploadResponse(
                dto.getId(),
                dto.getImageUrl(),
                isoTakenAt,
                (location != null ? location : null),
                (dto.getBrand() != null ? dto.getBrand() : brand),
                tagList,
                friendList,
                (memo != null ? memo : "")
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
            @RequestPart(value = "takenAt", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime takenAt,
            @RequestPart(value = "location", required = false) String location,
            @RequestPart(value = "brand", required = false) String brand,
            @RequestPart(value = "tagList", required = false) String tagListJson,
            @RequestPart(value = "friendIdList", required = false) String friendIdListJson,
            @RequestPart(value = "memo", required = false) String memo
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        if (image == null || image.isEmpty()) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "사진 파일은 필수입니다. (IMAGE_REQUIRED)");
        }

        PhotoUploadRequest req = new PhotoUploadRequest(
                image,
                null,           // qrUrl 없음 (갤러리 업로드)
                null,
                (takenAt != null) ? takenAt.toString() : null,
                location,
                brand,
                memo
        );

        PhotoResponseDto dto = photoService.uploadHybrid(
                userId,
                null,           // qrUrlOrPayload 없음
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
                (location != null ? location : null),
                (dto.getBrand() != null ? dto.getBrand() : brand),
                tagList,
                friendList,
                (memo != null ? memo : "")
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

        // 정렬 처리 (takenAt / createdAt / id)
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
        var pageDto = photoService.list(userId, pageable);
        DateTimeFormatter ISO = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

        List<PhotoListItemDto> items = pageDto.map(p -> PhotoListItemDto.builder()
                .photoId(p.getId())
                .imageUrl(p.getImageUrl())
                .takenAt(p.getTakenAt() != null ? p.getTakenAt().format(ISO) : null)
                // TODO: locationId → 실제 장소명 매핑 필요 시 Location 엔티티와 연동
                .location(null)
                .brand(p.getBrand())
                // TODO: 즐겨찾기 테이블 연결 시 실제 값으로 교체
                .isFavorite(false)
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
    // 4) 사진 삭제  (DELETE /api/photos/{id})
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
    // 내부용 DTO & 유틸
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

    private List<String> parseStringArray(String jsonArray) {
        if (jsonArray == null || jsonArray.isBlank()) return Collections.emptyList();
        try {
            return JSON.readValue(jsonArray, new TypeReference<List<String>>() {});
        } catch (Exception e) {
            // 형식 이상이면 무시하고 빈 리스트로
            return Collections.emptyList();
        }
    }

    private List<FriendDto> parseFriendList(String friendIdListJson) {
        if (friendIdListJson == null || friendIdListJson.isBlank()) return Collections.emptyList();
        try {
            List<Long> ids = JSON.readValue(friendIdListJson, new TypeReference<List<Long>>() {});
            List<FriendDto> result = new ArrayList<>();
            for (Long id : ids) {
                // TODO: UserRepository 통해 닉네임 조회 후 세팅
                result.add(new FriendDto(id, ""));
            }
            return result;
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }
}
