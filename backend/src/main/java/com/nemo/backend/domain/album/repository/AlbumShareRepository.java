package com.nemo.backend.domain.album.repository;

import com.nemo.backend.domain.album.entity.AlbumShare;
import com.nemo.backend.domain.album.entity.AlbumShare.Role;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface AlbumShareRepository extends JpaRepository<AlbumShare, Long> {

    List<AlbumShare> findByAlbumIdAndActiveTrue(Long albumId);

    Optional<AlbumShare> findByAlbumIdAndUserIdAndActiveTrue(Long albumId, Long userId);

    List<AlbumShare> findByUserIdAndActiveTrue(Long userId);

    boolean existsByAlbumIdAndUserIdAndActiveTrue(Long albumId, Long userId);
}
