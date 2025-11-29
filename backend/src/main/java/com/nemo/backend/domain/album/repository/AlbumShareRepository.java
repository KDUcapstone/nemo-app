package com.nemo.backend.domain.album.repository;

import com.nemo.backend.domain.album.entity.AlbumShare;
import com.nemo.backend.domain.album.entity.AlbumShare.Status;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface AlbumShareRepository extends JpaRepository<AlbumShare, Long> {

    List<AlbumShare> findByAlbumIdAndActiveTrue(Long albumId);

    Optional<AlbumShare> findByAlbumIdAndUserIdAndStatusAndActiveTrue(
            Long albumId, Long userId, Status status
    );

    List<AlbumShare> findByUserIdAndStatusAndActiveTrue(Long userId, Status status);

    boolean existsByAlbumIdAndUserIdAndActiveTrue(Long albumId, Long userId);

    // ✅ 강퇴된 사용자 재초대/재활성화를 위해 active 여부와 상관없이 조회
    Optional<AlbumShare> findByAlbumIdAndUserId(Long albumId, Long userId);

    Optional<AlbumShare> findByAlbumIdAndUserIdAndActiveTrue(Long albumId, Long userId);

    // ✅ 앨범별 ACCEPTED 멤버만 조회 (공유 멤버 목록용)
    List<AlbumShare> findByAlbumIdAndStatusAndActiveTrue(Long albumId, Status status);
}
