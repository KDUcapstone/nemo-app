// backend/src/main/java/com/nemo/backend/domain/photo/repository/PhotoRepository.java
package com.nemo.backend.domain.photo.repository;

import com.nemo.backend.domain.photo.entity.Photo;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface PhotoRepository extends JpaRepository<Photo, Long> {

    // QR 중복 체크
    Optional<Photo> findByQrHash(String qrHash);

    // 사용자별 목록 (삭제되지 않은 것만), 최신순
    Page<Photo> findByUserIdAndDeletedIsFalseOrderByCreatedAtDesc(Long userId, Pageable pageable);
}
