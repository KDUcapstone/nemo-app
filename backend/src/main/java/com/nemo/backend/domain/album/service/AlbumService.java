package com.nemo.backend.domain.album.service;

import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.repository.AlbumRepository;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.entity.Photo;                 // ✅ 추가
import com.nemo.backend.domain.photo.repository.PhotoRepository;   // ✅ 추가
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
// import jakarta.transaction.Transactional;                      // ❌ 제거
import org.springframework.transaction.annotation.Transactional;    // ✅ 교체
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AlbumService {

    private final AlbumRepository albumRepository;
    private final UserRepository userRepository;
    private final PhotoRepository photoRepository;                  // ✅ 주입

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

    @Transactional
    public void addPhoto(Long albumId, Long photoId, Long userId) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new IllegalArgumentException("Album not found"));
        if (!album.getUser().getId().equals(userId)) {
            throw new IllegalStateException("앨범 소유자가 아닙니다.");
        }
        Photo photo = photoRepository.findById(photoId)
                .orElseThrow(() -> new IllegalArgumentException("Photo not found"));
        if (!photo.getUserId().equals(userId)) {
            throw new IllegalStateException("본인 사진이 아닙니다.");
        }
        photo.setAlbum(album);
        photoRepository.save(photo);
    }

    @Transactional(readOnly = true) // ✅ spring-tx 사용하므로 readOnly OK
    public List<PhotoResponseDto> getPhotos(Long albumId, Long userId) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new IllegalArgumentException("Album not found"));
        if (!album.getUser().getId().equals(userId)) {
            throw new IllegalStateException("앨범 소유자가 아닙니다.");
        }
        return photoRepository
                .findByAlbumAndDeletedIsFalseOrderByCreatedAtDesc(album) // ✅ 리포지토리 메서드 필요
                .stream()
                .map(PhotoResponseDto::new)
                .collect(Collectors.toList());
    }

    @Transactional
    public void removePhoto(Long albumId, Long photoId, Long userId) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new IllegalArgumentException("Album not found"));
        Photo photo = photoRepository.findById(photoId)
                .orElseThrow(() -> new IllegalArgumentException("Photo not found"));
        if (!album.getUser().getId().equals(userId) || !photo.getUserId().equals(userId)) {
            throw new IllegalStateException("권한이 없습니다.");
        }
        if (photo.getAlbum() != null && photo.getAlbum().getId().equals(albumId)) {
            photo.setAlbum(null);
            photoRepository.save(photo);
        }
    }
}
