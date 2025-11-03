// backend/src/main/java/com/nemo/backend/domain/album/controller/AlbumController.java
package com.nemo.backend.domain.album.controller;

import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.service.AlbumService;
import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;

@RestController
@RequestMapping("/api/albums")
public class AlbumController {

    private final AlbumService albumService;
    private final JwtTokenProvider jwtTokenProvider;
    private final RefreshTokenRepository refreshTokenRepository;

    public AlbumController(AlbumService albumService,
                           JwtTokenProvider jwtTokenProvider,
                           RefreshTokenRepository refreshTokenRepository) {
        this.albumService = albumService;
        this.jwtTokenProvider = jwtTokenProvider;
        this.refreshTokenRepository = refreshTokenRepository;
    }

    // GET /api/albums : 로그인 사용자의 앨범 목록
    @GetMapping
    public ResponseEntity<?> getAlbums(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader) {
        Long userId = extractUserId(authorizationHeader);
        List<AlbumSummaryResponse> content = albumService.getAlbums(userId);
        return ResponseEntity.ok(
                java.util.Map.of(
                        "content", content,
                        "page", java.util.Map.of(
                                "size", content.size(),
                                "totalElements", content.size(),
                                "totalPages", 1,
                                "number", 0
                        )
                )
        );
    }

    // POST /api/albums
    @PostMapping
    public ResponseEntity<AlbumDetailResponse> create(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @Valid @RequestBody CreateAlbumRequest req) {
        Long userId = extractUserId(authorizationHeader);
        return ResponseEntity.status(201).body(albumService.createAlbum(userId, req));
    }

    // GET /api/albums/{albumId}
    @GetMapping("/{albumId}")
    public ResponseEntity<AlbumDetailResponse> get(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId) {
        Long userId = extractUserId(authorizationHeader);
        return ResponseEntity.ok(albumService.getAlbum(userId, albumId));
    }

    // PUT /api/albums/{albumId}
    @PutMapping("/{albumId}")
    public ResponseEntity<AlbumDetailResponse> update(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId,
            @RequestBody UpdateAlbumRequest req) {
        Long userId = extractUserId(authorizationHeader);
        return ResponseEntity.ok(albumService.updateAlbum(userId, albumId, req));
    }

    // POST /api/albums/{albumId}/photos (여러 장 추가)
    @PostMapping("/{albumId}/photos")
    public ResponseEntity<Void> addPhotos(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId,
            @Valid @RequestBody PhotoIdListRequest req) {
        Long userId = extractUserId(authorizationHeader);
        albumService.addPhotos(userId, albumId, req.getPhotoIds()); // ✅ getPhotoIds 로 변경
        return ResponseEntity.noContent().build();
    }

    // DELETE /api/albums/{albumId}/photos (여러 장 삭제)
    @DeleteMapping("/{albumId}/photos")
    public ResponseEntity<Void> removePhotos(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId,
            @Valid @RequestBody PhotoIdListRequest req) {
        Long userId = extractUserId(authorizationHeader);
        albumService.removePhotos(userId, albumId, req.getPhotoIds()); // ✅ getPhotoIds 로 변경
        return ResponseEntity.noContent().build();
    }

    // DELETE /api/albums/{albumId}
    @DeleteMapping("/{albumId}")
    public ResponseEntity<?> delete(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId) {
        Long userId = extractUserId(authorizationHeader);
        albumService.deleteAlbum(userId, albumId);
        return ResponseEntity.noContent().build();
    }

    /** 액세스 토큰 서명 검증 + refresh 존재 확인 (PhotoController와 동일 규칙) */
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
