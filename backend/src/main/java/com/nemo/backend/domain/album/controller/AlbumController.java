package com.nemo.backend.domain.album.controller;

import com.nemo.backend.domain.album.dto.AlbumCreateRequest;
import com.nemo.backend.domain.album.dto.AlbumResponse;
import com.nemo.backend.domain.album.dto.AlbumUpdateRequest;
import com.nemo.backend.domain.album.service.AlbumService;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@SecurityRequirement(name = "BearerAuth")  // ✅ Swagger Authorize 버튼에서 자동 인증 연결
@RestController
@RequestMapping("/api/albums")
@RequiredArgsConstructor
public class AlbumController {

    private final AlbumService albumService;
    private final JwtTokenProvider jwtTokenProvider;
    private final RefreshTokenRepository refreshTokenRepository;

    /** JWT 토큰에서 userId 추출 (모든 인증 공통 메서드) */
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

    // -----------------------------------------------------
    // 🎨 [1] 앨범 CRUD
    // -----------------------------------------------------

    @Operation(summary = "앨범 생성", description = "userId, name, description을 입력해 새 앨범 생성")
    @PostMapping
    public ResponseEntity<AlbumResponse> createAlbum(@RequestBody AlbumCreateRequest req) {
        return ResponseEntity.ok(albumService.createAlbum(req));
    }

    @Operation(summary = "앨범 단건 조회", description = "앨범 id로 단일 앨범을 조회")
    @GetMapping("/{id}")
    public ResponseEntity<AlbumResponse> getAlbum(@PathVariable Long id) {
        return ResponseEntity.ok(albumService.getAlbum(id));
    }

    @Operation(summary = "사용자별 앨범 목록", description = "userId로 해당 사용자의 모든 앨범 조회")
    @GetMapping("/user/{userId}")
    public ResponseEntity<List<AlbumResponse>> getAlbumsByUser(@PathVariable Long userId) {
        return ResponseEntity.ok(albumService.getAlbumsByUser(userId));
    }

    @Operation(summary = "앨범 수정", description = "앨범의 이름/설명을 변경")
    @PutMapping("/{id}")
    public ResponseEntity<AlbumResponse> updateAlbum(
            @PathVariable Long id,
            @RequestBody AlbumUpdateRequest req) {
        return ResponseEntity.ok(albumService.updateAlbum(id, req));
    }

    @Operation(summary = "앨범 삭제", description = "해당 id의 앨범을 삭제")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAlbum(@PathVariable Long id) {
        albumService.deleteAlbum(id);
        return ResponseEntity.noContent().build();
    }

    // -----------------------------------------------------
    // 📸 [2] 앨범과 사진 연동
    // -----------------------------------------------------

    @Operation(summary = "앨범에 사진 추가", description = "앨범에 사진을 연결 (owner만 가능)")
    @PostMapping("/{albumId}/photos/{photoId}")
    public ResponseEntity<Void> addPhoto(
            @PathVariable Long albumId,
            @PathVariable Long photoId,
            @Parameter(hidden = true)
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader) {
        Long userId = extractUserId(authorizationHeader);
        albumService.addPhoto(albumId, photoId, userId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "앨범에서 사진 제거", description = "앨범에서 특정 사진을 제거 (owner만 가능)")
    @DeleteMapping("/{albumId}/photos/{photoId}")
    public ResponseEntity<Void> removePhoto(
            @PathVariable Long albumId,
            @PathVariable Long photoId,
            @Parameter(hidden = true)
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader) {
        Long userId = extractUserId(authorizationHeader);
        albumService.removePhoto(albumId, photoId, userId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "앨범 내 사진 목록", description = "특정 앨범에 포함된 모든 사진을 조회")
    @GetMapping("/{albumId}/photos")
    public ResponseEntity<List<PhotoResponseDto>> getPhotosInAlbum(
            @PathVariable Long albumId,
            @Parameter(hidden = true)
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader) {
        Long userId = extractUserId(authorizationHeader);
        return ResponseEntity.ok(albumService.getPhotos(albumId, userId));
    }
}
