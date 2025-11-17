package com.nemo.backend.domain.album.repository;

import com.nemo.backend.domain.album.entity.AlbumShare;
import com.nemo.backend.domain.album.entity.AlbumShare.Status;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface AlbumShareRepository extends JpaRepository<AlbumShare, Long> {

    List<AlbumShare> findByAlbumIdAndStatusAndActiveTrue(Long albumId, Status status);

    List<AlbumShare> findByAlbumIdAndActiveTrue(Long albumId);

    Optional<AlbumShare> findByAlbumIdAndUserIdAndStatusAndActiveTrue(
            Long albumId, Long userId, Status status
    );

    List<AlbumShare> findByUserIdAndStatusAndActiveTrue(Long userId, Status status);

    List<AlbumShare> findByUserIdAndActiveTrue(Long userId);

    boolean existsByAlbumIdAndUserIdAndActiveTrue(Long albumId, Long userId);

    // ⭐ 추가해야 하는 부분
    Optional<AlbumShare> findByAlbumIdAndUserIdAndActiveTrue(Long albumId, Long userId);
}
