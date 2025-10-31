package com.nemo.backend.domain.photo.controller;

import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.service.PhotoService;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.parameters.RequestBody;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;

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
        return ResponseEntity.status(HttpStatus.OK).body(dto); // 필요 시 CREATED로 변경 가능
    }

    @GetMapping
    public ResponseEntity<Page<PhotoResponseDto>> list(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            Pageable pageable) {
        Long userId = extractUserId(authorizationHeader);
        return ResponseEntity.ok(photoService.list(userId, pageable));
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
