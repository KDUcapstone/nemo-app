// backend/src/main/java/com/nemo/backend/domain/auth/token/RefreshTokenRepository.java
package com.nemo.backend.domain.auth.token;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    /** UserAuthController.extractUserId()에서 사용 */
    Optional<RefreshToken> findFirstByUserId(Long userId);

    /** AuthService.logout(), deleteAccount()에서 사용 */
    void deleteByUserId(Long userId);
}
