package com.nemo.backend.domain.user.repository;

import com.nemo.backend.domain.user.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Repository for {@link User} persistence.
 * -------------------------------------------
 * - 기본 CRUD (findById, save 등)
 * - 이메일 단건 조회 (findByEmail)
 * - 닉네임/이메일 기반 검색 기능 추가 (searchByNicknameOrEmail)
 */
@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    /**
     * ✅ 이메일로 사용자 조회
     * -----------------------------
     * - 로그인 시 사용자 존재 여부 확인용
     */
    Optional<User> findByEmail(String email);

    /**
     * ✅ 닉네임 또는 이메일 일부로 사용자 검색
     * -----------------------------
     * - 친구 검색 API에서 사용
     * - 대소문자 구분 없이 검색 (LOWER)
     * - LIKE 검색으로 부분 일치 처리
     *
     * 예시:
     *  keyword = "네컷"  →  닉네임에 '네컷'이 포함된 모든 사용자 조회
     */
    @Query("SELECT u FROM User u WHERE LOWER(u.nickname) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(u.email) LIKE LOWER(CONCAT('%', :keyword, '%'))")
    List<User> searchByNicknameOrEmail(String keyword);
    boolean existsByEmail(String email);
}
