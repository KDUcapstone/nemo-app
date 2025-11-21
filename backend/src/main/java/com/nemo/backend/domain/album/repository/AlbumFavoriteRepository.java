package com.nemo.backend.domain.album.repository;

import com.nemo.backend.domain.album.entity.AlbumFavorite;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AlbumFavoriteRepository extends JpaRepository<AlbumFavorite, Long> {

    boolean existsByAlbumIdAndUserId(Long albumId, Long userId);

    void deleteByAlbumIdAndUserId(Long albumId, Long userId);

    List<AlbumFavorite> findByUserId(Long userId);
}
