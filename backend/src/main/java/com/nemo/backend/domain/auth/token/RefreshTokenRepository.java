package com.nemo.backend.domain.auth.token;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

/**
 * Repository for {@link RefreshToken} persistence.
 */
@Repository
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {
    Optional<RefreshToken> findByToken(String token);
    void deleteByUserId(Long userId);

    /** userId로 현재 유효한(미삭제) 리프레시 토큰 존재 여부 확인용 */
    Optional<RefreshToken> findFirstByUserId(Long userId);
}
