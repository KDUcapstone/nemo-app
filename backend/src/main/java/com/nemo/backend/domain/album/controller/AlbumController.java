package com.nemo.backend.domain.album.controller;

import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.service.AlbumService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/albums")
@RequiredArgsConstructor
public class AlbumController {

    private final AlbumService albumService;

    @PostMapping
    public ResponseEntity<AlbumResponse> create(@RequestBody AlbumCreateRequest req) {
        return ResponseEntity.ok(albumService.createAlbum(req));
    }

    @GetMapping("/user/{userId}")
    public ResponseEntity<List<AlbumResponse>> getByUser(@PathVariable Long userId) {
        return ResponseEntity.ok(albumService.getAlbumsByUser(userId));
    }

    @GetMapping("/{id}")
    public ResponseEntity<AlbumResponse> getOne(@PathVariable Long id) {
        return ResponseEntity.ok(albumService.getAlbum(id));
    }

    @PutMapping("/{id}")
    public ResponseEntity<AlbumResponse> update(
            @PathVariable Long id,
            @RequestBody AlbumUpdateRequest req
    ) {
        return ResponseEntity.ok(albumService.updateAlbum(id, req));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        albumService.deleteAlbum(id);
        return ResponseEntity.noContent().build();
    }
}
