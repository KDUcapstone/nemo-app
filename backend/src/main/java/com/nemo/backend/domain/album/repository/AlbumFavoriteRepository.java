package com.nemo.backend.domain.album.repository;

import com.nemo.backend.domain.album.entity.AlbumFavorite;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AlbumFavoriteRepository extends JpaRepository<AlbumFavorite, Long> {

    boolean existsByAlbumIdAndUserId(Long albumId, Long userId);

    void deleteByAlbumIdAndUserId(Long albumId, Long userId);

    List<AlbumFavorite> findByUserId(Long userId);

    // ✅ 앨범 삭제 시, 해당 앨범에 걸린 즐겨찾기 전부 제거
    void deleteByAlbumId(Long albumId);

    // 특정 앨범이 즐겨찾기 된 모든 레코드 삭제 (앨범 삭제 시)
    void deleteAllByAlbumId(Long albumId);

    // 특정 사용자가 즐겨찾기한 모든 앨범 레코드 삭제 (회원탈퇴 시)
    void deleteAllByUserId(Long userId);
}
