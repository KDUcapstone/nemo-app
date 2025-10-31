// backend/src/main/java/com/nemo/backend/domain/album/controller/AlbumController.java
package com.nemo.backend.domain.album.controller;

import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.service.AlbumService;

@RestController
@RequestMapping("/api/albums")
public class AlbumController {

    private final AlbumService albumService;
    public AlbumController(AlbumService albumService) { this.albumService = albumService; }

    // GET /api/albums : 페이지네이션 구조로 응답
    @GetMapping
    public ResponseEntity<?> getAlbums() {
        List<AlbumSummaryResponse> content = albumService.getAlbums();
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
    public ResponseEntity<AlbumDetailResponse> create(@Valid @RequestBody CreateAlbumRequest req) {
        return ResponseEntity.status(201).body(albumService.createAlbum(req));
    }

    // GET /api/albums/{albumId}
    @GetMapping("/{albumId}")
    public ResponseEntity<AlbumDetailResponse> get(@PathVariable Long albumId) {
        return ResponseEntity.ok(albumService.getAlbum(albumId));
    }

    // PUT /api/albums/{albumId}
    @PutMapping("/{albumId}")
    public ResponseEntity<AlbumDetailResponse> update(@PathVariable Long albumId,
                                                      @RequestBody UpdateAlbumRequest req) {
        return ResponseEntity.ok(albumService.updateAlbum(albumId, req));
    }

    // POST /api/albums/{albumId}/photos (여러 장 추가)
    @PostMapping("/{albumId}/photos")
    public ResponseEntity<Void> addPhotos(@PathVariable Long albumId,
                                          @Valid @RequestBody PhotoIdListRequest req) {
        albumService.addPhotos(albumId, req.getPhotoIdList());
        return ResponseEntity.noContent().build();
    }

    // DELETE /api/albums/{albumId}/photos (여러 장 삭제)
    @DeleteMapping("/{albumId}/photos")
    public ResponseEntity<Void> removePhotos(@PathVariable Long albumId,
                                             @Valid @RequestBody PhotoIdListRequest req) {
        albumService.removePhotos(albumId, req.getPhotoIdList());
        return ResponseEntity.noContent().build();
    }

    // DELETE /api/albums/{albumId}
    @DeleteMapping("/{albumId}")
    public ResponseEntity<?> delete(@PathVariable Long albumId) {
        albumService.deleteAlbum(albumId);
        return ResponseEntity.noContent().build();
    }
}
