// backend/src/main/java/com/nemo/backend/domain/album/controller/AlbumController.java
package com.nemo.backend.domain.album.controller;

import java.util.List;

import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.service.AlbumService;
import com.nemo.backend.domain.album.service.AlbumShareService;
import com.nemo.backend.domain.auth.util.AuthExtractor;  // 🔥 공통 인증 유틸
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/albums")
@RequiredArgsConstructor // ⭐ 생성자 자동 생성 (final 필드만)
public class AlbumController {

    private final AlbumService albumService;
    private final AuthExtractor authExtractor;

    // ========================================================
    // 1) GET /api/albums : 로그인 사용자의 앨범 목록 조회
    // ========================================================
    @GetMapping
    public ResponseEntity<?> getAlbums(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader) {

        Long userId = authExtractor.extractUserId(authorizationHeader); // 🔑 공통 인증

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

    // ========================================================
    // 2) POST /api/albums : 앨범 생성
    // ========================================================
    @PostMapping
    public ResponseEntity<AlbumDetailResponse> create(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @Valid @RequestBody CreateAlbumRequest req) {

        Long userId = authExtractor.extractUserId(authorizationHeader);
        AlbumDetailResponse response = albumService.createAlbum(userId, req);

        return ResponseEntity.status(201).body(response);
    }

    // ========================================================
    // 3) GET /api/albums/{albumId} : 앨범 상세 조회
    // ========================================================
    @GetMapping("/{albumId}")
    public ResponseEntity<AlbumDetailResponse> get(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId) {

        Long userId = authExtractor.extractUserId(authorizationHeader);
        return ResponseEntity.ok(albumService.getAlbum(userId, albumId));
    }

    // ========================================================
    // 4) PUT /api/albums/{albumId} : 앨범 정보 수정
    // ========================================================
    @PutMapping("/{albumId}")
    public ResponseEntity<AlbumDetailResponse> update(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId,
            @RequestBody UpdateAlbumRequest req) {

        Long userId = authExtractor.extractUserId(authorizationHeader);
        return ResponseEntity.ok(albumService.updateAlbum(userId, albumId, req));
    }

    // ========================================================
    // 5) POST /api/albums/{albumId}/photos : 사진 여러 장 추가
    // ========================================================
    @PostMapping("/{albumId}/photos")
    public ResponseEntity<Void> addPhotos(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId,
            @Valid @RequestBody PhotoIdListRequest req) {

        Long userId = authExtractor.extractUserId(authorizationHeader);
        albumService.addPhotos(userId, albumId, req.getPhotoIds());
        return ResponseEntity.noContent().build();
    }

    // ========================================================
    // 6) DELETE /api/albums/{albumId}/photos : 사진 여러 장 삭제
    // ========================================================
    @DeleteMapping("/{albumId}/photos")
    public ResponseEntity<Void> removePhotos(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId,
            @Valid @RequestBody PhotoIdListRequest req) {

        Long userId = authExtractor.extractUserId(authorizationHeader);
        albumService.removePhotos(userId, albumId, req.getPhotoIds());
        return ResponseEntity.noContent().build();
    }

    // ========================================================
    // 7) DELETE /api/albums/{albumId} : 앨범 삭제
    // ========================================================
    @DeleteMapping("/{albumId}")
    public ResponseEntity<?> delete(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId) {

        Long userId = authExtractor.extractUserId(authorizationHeader);
        albumService.deleteAlbum(userId, albumId);
        return ResponseEntity.noContent().build();
    }

    // ========================================================
    // 8) POST /api/albums/{albumId}/thumbnail : 썸네일 생성/지정
    // ========================================================
    @PostMapping(
            value = "/{albumId}/thumbnail",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public ResponseEntity<AlbumThumbnailResponse> updateThumbnail(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId,

            // 예시 1: 앨범 내 사진 선택 (JSON Part, e.g. {"photoId": 125})
            @RequestPart(value = "photoId", required = false) Long photoId,

            // 예시 2: 직접 업로드 (Multipart file)
            @RequestPart(value = "file", required = false) MultipartFile file
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        AlbumThumbnailResponse resp =
                albumService.updateThumbnail(userId, albumId, photoId, file);

        return ResponseEntity.ok(resp);
    }
}
