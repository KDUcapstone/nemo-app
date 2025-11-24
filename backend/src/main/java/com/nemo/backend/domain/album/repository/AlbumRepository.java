// backend/src/main/java/com/nemo/backend/domain/album/repository/AlbumRepository.java
package com.nemo.backend.domain.album.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import com.nemo.backend.domain.album.entity.Album;

import java.util.List;

public interface AlbumRepository extends JpaRepository<Album, Long> {

    // ✅ 사용자가 소유한 앨범만 조회
    List<Album> findByUserId(Long userId);
}
