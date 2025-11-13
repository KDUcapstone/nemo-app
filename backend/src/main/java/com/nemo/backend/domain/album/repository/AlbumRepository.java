// backend/src/main/java/com/nemo/backend/domain/album/repository/AlbumRepository.java
package com.nemo.backend.domain.album.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import com.nemo.backend.domain.album.entity.Album;

public interface AlbumRepository extends JpaRepository<Album, Long> {
}
