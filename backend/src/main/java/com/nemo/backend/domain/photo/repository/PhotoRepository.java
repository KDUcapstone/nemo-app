// backend/src/main/java/com/nemo/backend/domain/photo/repository/PhotoRepository.java
package com.nemo.backend.domain.photo.repository;

import com.nemo.backend.domain.photo.entity.Photo;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PhotoRepository extends JpaRepository<Photo, Long> {

    Page<Photo> findByUserIdAndDeletedIsFalseOrderByCreatedAtDesc(Long userId, Pageable pageable);

    // ✅ 즐겨찾기만 필터
    Page<Photo> findByUserIdAndDeletedIsFalseAndFavoriteTrueOrderByCreatedAtDesc(Long userId, Pageable pageable);

    // ✅ 특정 사진이 살아있는지 검사할 때 사용
    Optional<Photo> findByIdAndDeletedIsFalse(Long id);

    // ✅ 타임라인용: 촬영일시 기준 내림차순 전체 조회
    List<Photo> findByUserIdAndDeletedIsFalseOrderByTakenAtDesc(Long userId);
}
