package com.nemo.backend.domain.photo.controller;

import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.service.PhotoService;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;

import com.nemo.backend.domain.photo.dto.PhotoListItemDto;        // ★ 추가
import com.nemo.backend.web.PagedResponse;                 // ★ 추가
import com.nemo.backend.web.PageMetaDto;                   // ★ 추가

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.parameters.RequestBody;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.*;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

@SecurityRequirement(name = "BearerAuth")
@RestController
@RequestMapping("/api/photos")
public class PhotoController {

    private final PhotoService photoService;
    private final JwtTokenProvider jwtTokenProvider;
    private final RefreshTokenRepository refreshTokenRepository;

    @Autowired
    public PhotoController(PhotoService photoService,
                           JwtTokenProvider jwtTokenProvider,
                           RefreshTokenRepository refreshTokenRepository) {
        this.photoService = photoService;
        this.jwtTokenProvider = jwtTokenProvider;
        this.refreshTokenRepository = refreshTokenRepository;
    }

    /**
     * 📸 사진 업로드 (프론트 현재 포맷 완전 호환)
     * - multipart/form-data
     *   - file part:   image (선택)
     *   - form fields: qrCode(필수), brand/location/takenAt/tagList/friendIdList/memo(선택)
     * - image가 없으면 qrCode(URL)에서 백엔드가 자산 추출
     * - brand/takenAt 비어오면 백엔드 추론/기본값
     */
    @Operation(summary = "QR 업로드(프론트 호환 포맷)",
            requestBody = @RequestBody(content = @Content(mediaType = MediaType.MULTIPART_FORM_DATA_VALUE)))
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<PhotoResponseDto> upload(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @RequestPart(value = "image", required = false) MultipartFile image,
            @RequestParam("qrCode") String qrCode,
            @RequestParam(value = "brand", required = false) String brand,
            @RequestParam(value = "location", required = false) String location,
            @RequestParam(value = "takenAt", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime takenAt,
            @RequestParam(value = "tagList", required = false) String tagListJson,
            @RequestParam(value = "friendIdList", required = false) String friendIdListJson,
            @RequestParam(value = "memo", required = false) String memo
    ) {
        Long userId = extractUserId(authorizationHeader);
        PhotoResponseDto dto = photoService.uploadHybrid(
                userId, qrCode, image, brand, location, takenAt, tagListJson, friendIdListJson, memo
        );
        return ResponseEntity.status(HttpStatus.OK).body(dto);
    }

    /**
     * ✅ 사용자 사진 목록 조회 (프론트 명세 스키마로 변환)
     * 쿼리 파라미터: favorite, tag, sort, page, size
     * sort 예: takenAt,desc | takenAt,asc (기본: takenAt,desc)
     */
    @GetMapping
    public ResponseEntity<PagedResponse<PhotoListItemDto>> list(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @RequestParam(value = "favorite", required = false) Boolean favorite,
            @RequestParam(value = "tag", required = false) String tag,
            @RequestParam(value = "sort", required = false, defaultValue = "takenAt,desc") String sortBy,
            @RequestParam(value = "page", required = false, defaultValue = "0") Integer page,
            @RequestParam(value = "size", required = false, defaultValue = "20") Integer size
    ) {
        Long userId = extractUserId(authorizationHeader);

        // sort 파싱
        Sort sort = Sort.by(Sort.Direction.DESC, "takenAt");
        if (sortBy != null && !sortBy.isBlank()) {
            String[] parts = sortBy.split(",");
            String field = parts[0].trim();
            Sort.Direction dir = (parts.length > 1 && "asc".equalsIgnoreCase(parts[1].trim()))
                    ? Sort.Direction.ASC : Sort.Direction.DESC;

            // 허용 필드만 매핑
            switch (field) {
                case "takenAt" -> sort = Sort.by(dir, "takenAt");
                case "createdAt" -> sort = Sort.by(dir, "createdAt");
                case "photoId", "id" -> sort = Sort.by(dir, "id");
                default -> sort = Sort.by(Sort.Direction.DESC, "takenAt");
            }
        }

        Pageable pageable = PageRequest.of(page, size, sort);

        // 기존 서비스 결과(Page<PhotoResponseDto>)를 프론트 스키마로 변환
        var pageDto = photoService.list(userId, pageable);
        DateTimeFormatter ISO = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

        List<PhotoListItemDto> items = pageDto.map(p -> PhotoListItemDto.builder()
                .photoId(p.getId())
                .imageUrl(p.getImageUrl())
                .takenAt(p.getTakenAt() != null ? p.getTakenAt().format(ISO) : null)
                .location(null)      // 위치명 컬럼 없으면 null/"" 유지. 추후 엔티티에 locationName 추가 후 매핑.
                .brand(p.getBrand())
                .isFavorite(false)   // 즐겨찾기 미구현이면 false
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

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable("id") Long photoId) {
        Long userId = extractUserId(authorizationHeader);
        photoService.delete(userId, photoId);
        return ResponseEntity.noContent().build();
    }

    /** 액세스 토큰 서명 검증 + refresh 존재 확인 */
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
        if (!hasRefresh) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }
        return userId;
    }
}
