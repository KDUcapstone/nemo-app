// backend/src/main/java/com/nemo/backend/domain/photo/repository/PhotoRepository.java
package com.nemo.backend.domain.photo.repository;

import com.nemo.backend.domain.photo.entity.Photo;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PhotoRepository extends JpaRepository<Photo, Long> {

    Optional<Photo> findByQrHash(String qrHash);

    Page<Photo> findByUserIdAndDeletedIsFalseOrderByCreatedAtDesc(Long userId, Pageable pageable);

    // ✅ 앨범 내 사진들 (삭제 안 된 것만) 최신순
    List<Photo> findByAlbum_IdAndDeletedIsFalseOrderByCreatedAtDesc(Long albumId);

    // ✅ 특정 사진이 살아있는지 검사할 때 사용
    Optional<Photo> findByIdAndDeletedIsFalse(Long id);
}
