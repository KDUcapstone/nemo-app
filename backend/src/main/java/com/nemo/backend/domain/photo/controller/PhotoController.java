package com.nemo.backend.domain.photo.controller;

import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
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
public class PhotoController {

    private final PhotoService photoService;
    private final JwtTokenProvider jwtTokenProvider;
    private final RefreshTokenRepository refreshTokenRepository;

    public PhotoController(PhotoService photoService,
                           JwtTokenProvider jwtTokenProvider,
                           RefreshTokenRepository refreshTokenRepository) {
        this.photoService = photoService;
        this.jwtTokenProvider = jwtTokenProvider;
        this.refreshTokenRepository = refreshTokenRepository;
    }

    @Operation(summary = "QR/파일 업로드(둘 중 하나)", requestBody = @RequestBody(
            content = @Content(mediaType = MediaType.MULTIPART_FORM_DATA_VALUE)))
    @PostMapping(consumes = { MediaType.MULTIPART_FORM_DATA_VALUE, MediaType.APPLICATION_FORM_URLENCODED_VALUE, MediaType.APPLICATION_JSON_VALUE },
            produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<PhotoUploadResponse> upload(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,

            // A) 순수 파일 업로드 경로
            @RequestPart(value = "image", required = false) MultipartFile image,

            // B) URL 업로드 경로 (이전 프론트 호환: qrCode/qrUrl 둘 다 받되, qrUrl 우선)
            @RequestParam(value = "qrUrl",  required = false) String qrUrl,
            @RequestParam(value = "qrCode", required = false) String qrCode,

            // 보조 필드들
            @RequestParam(value = "brand",    required = false) String brand,
            @RequestParam(value = "location", required = false) String location,
            @RequestParam(value = "takenAt",  required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime takenAt,

            @RequestParam(value = "tagList",       required = false) String tagListJson,
            @RequestParam(value = "friendIdList",  required = false) String friendIdListJson,
            @RequestParam(value = "memo",          required = false) String memo
    ) {
        Long userId = extractUserId(authorizationHeader);

        // 하나의 DTO로 합성해 서비스로 전달
        PhotoUploadRequest req = new PhotoUploadRequest(
                image,
                (qrUrl != null && !qrUrl.isBlank()) ? qrUrl : qrCode, // qrUrl 우선, 없으면 qrCode 사용
                qrCode,
                (takenAt != null) ? takenAt.toString() : null,
                location,
                brand,
                memo
        );

        PhotoResponseDto dto = photoService.uploadHybrid(
                userId,
                req.qrUrl(),  // 서비스에서 URL/직접파일 분기
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
                : LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);

        PhotoUploadResponse resp = new PhotoUploadResponse(
                dto.getId(),
                dto.getImageUrl(),
                isoTakenAt,
                (location != null ? location : ""),
                (dto.getBrand() != null ? dto.getBrand() : ""),
                Collections.emptyList(),
                Collections.emptyList(),
                (memo != null ? memo : "")
        );
        return ResponseEntity.status(HttpStatus.CREATED).contentType(MediaType.APPLICATION_JSON).body(resp);
    }

    @GetMapping(produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<PagedResponse<PhotoListItemDto>> list(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @RequestParam(value = "favorite", required = false) Boolean favorite,
            @RequestParam(value = "tag", required = false) String tag,
            @RequestParam(value = "sort", required = false, defaultValue = "takenAt,desc") String sortBy,
            @RequestParam(value = "page", required = false, defaultValue = "0") Integer page,
            @RequestParam(value = "size", required = false, defaultValue = "20") Integer size
    ) {
        Long userId = extractUserId(authorizationHeader);

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
                .location(null)
                .brand(p.getBrand())
                .isFavorite(false)
                .build()
        ).getContent();

        PageMetaDto meta = new PageMetaDto(pageDto.getSize(), pageDto.getTotalElements(), pageDto.getTotalPages(), pageDto.getNumber());
        return ResponseEntity.ok(new PagedResponse<>(items, meta));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@RequestHeader(value = "Authorization", required = false) String authorizationHeader,
                                       @PathVariable("id") Long photoId) {
        Long userId = extractUserId(authorizationHeader);
        photoService.delete(userId, photoId);
        return ResponseEntity.noContent().build();
    }

    private Long extractUserId(String authorizationHeader) {
        if (authorizationHeader == null || !authorizationHeader.startsWith("Bearer ")) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }
        String token = authorizationHeader.substring(7);
        if (!jwtTokenProvider.validateToken(token)) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }
        Long userId = jwtTokenProvider.getUserId(token);
        boolean hasRefresh = refreshTokenRepository.findFirstByUserId(userId).isPresent();
        if (!hasRefresh) throw new ApiException(ErrorCode.UNAUTHORIZED);
        return userId;
    }

    // 명세용 응답 DTO
    public static record PhotoUploadResponse(
            long photoId, String imageUrl, String takenAt,
            String location, String brand,
            List<String> tagList, List<FriendDto> friendList, String memo
    ) {}
    public static record FriendDto(long userId, String nickname) {}
}
