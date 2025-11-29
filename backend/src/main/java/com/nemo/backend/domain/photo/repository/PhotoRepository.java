// backend/src/main/java/com/nemo/backend/domain/photo/repository/PhotoRepository.java
package com.nemo.backend.domain.photo.repository;

import com.nemo.backend.domain.photo.entity.Photo;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PhotoRepository extends JpaRepository<Photo, Long> {

    // ✅ 사진 목록 조회용 동적 필터 (favorite / brand / tag)
    @Query("""
        SELECT p
        FROM Photo p
        WHERE p.userId = :userId
          AND p.deleted = false
          AND (:favorite IS NULL OR p.favorite = :favorite)
          AND (:brand IS NULL OR p.brand = :brand)
          AND (:tag IS NULL OR p.memo LIKE %:tag%)
        """)
    Page<Photo> findForList(
            @Param("userId") Long userId,
            @Param("favorite") Boolean favorite,
            @Param("brand") String brand,
            @Param("tag") String tag,
            Pageable pageable
    );

    // ✅ 특정 사진이 살아있는지 검사할 때 사용
    Optional<Photo> findByIdAndDeletedIsFalse(Long id);

    // ✅ 타임라인용: 촬영일시 기준 내림차순 전체 조회 (그대로 유지)
    List<Photo> findByUserIdAndDeletedIsFalseOrderByTakenAtDesc(Long userId);

    // ✅ 유저의 전체 사진 개수 조회 (삭제되지 않은 것만)
    int countByUserIdAndDeletedIsFalse(Long userId);
}
