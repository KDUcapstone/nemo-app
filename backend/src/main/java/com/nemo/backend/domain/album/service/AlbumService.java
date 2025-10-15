package com.nemo.backend.domain.album.service;

import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.repository.AlbumRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AlbumService {

    private final AlbumRepository albumRepository;
    private final UserRepository userRepository;

    public AlbumResponse createAlbum(AlbumCreateRequest req) {
        User user = userRepository.findById(req.getUserId())
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        Album album = Album.builder()
                .name(req.getName())
                .description(req.getDescription())
                .user(user)
                .build();

        return AlbumResponse.fromEntity(albumRepository.save(album));
    }

    public List<AlbumResponse> getAlbumsByUser(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        return albumRepository.findByUser(user)
                .stream()
                .map(AlbumResponse::fromEntity)
                .collect(Collectors.toList());
    }

    public AlbumResponse getAlbum(Long id) {
        Album album = albumRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Album not found"));
        return AlbumResponse.fromEntity(album);
    }

    public AlbumResponse updateAlbum(Long id, AlbumUpdateRequest req) {
        Album album = albumRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Album not found"));

        if (req.getName() != null) album.setName(req.getName());
        if (req.getDescription() != null) album.setDescription(req.getDescription());

        return AlbumResponse.fromEntity(albumRepository.save(album));
    }

    public void deleteAlbum(Long id) {
        albumRepository.deleteById(id);
    }
}
