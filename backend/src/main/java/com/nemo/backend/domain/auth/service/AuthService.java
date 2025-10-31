// backend/src/main/java/com/nemo/backend/domain/auth/service/AuthService.java
package com.nemo.backend.domain.auth.service;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;

@Service
@Transactional
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;

    public AuthService(UserRepository userRepository,
                       RefreshTokenRepository refreshTokenRepository,
                       PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
    }

    /** (유지) 기존 시그니처 – 내부적으로 비밀번호 null 위임 */
    public void deleteAccount(Long userId) {
        deleteAccount(userId, null);
    }

    /** (신규) 비밀번호 검증 포함 탈퇴 */
    public void deleteAccount(Long userId, String rawPassword) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("해당 사용자를 찾을 수 없습니다."));

        if (rawPassword == null || rawPassword.isBlank()
                || !passwordEncoder.matches(rawPassword, user.getPassword())) {
            throw new IllegalArgumentException("비밀번호가 일치하지 않습니다.");
        }

        // 사용자 토큰 정리
        refreshTokenRepository.deleteByUserId(userId);

        // 사용자 삭제
        userRepository.delete(user);
    }
}
