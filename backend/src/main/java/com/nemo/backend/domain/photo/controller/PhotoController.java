package com.nemo.backend.domain.photo.controller;

import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.service.PhotoService;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

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

    @PostMapping
    public ResponseEntity<PhotoResponseDto> upload(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @RequestPart("qr") MultipartFile qrFile) {
        Long userId = extractUserId(authorizationHeader);
        return ResponseEntity.ok(photoService.upload(userId, qrFile));
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
