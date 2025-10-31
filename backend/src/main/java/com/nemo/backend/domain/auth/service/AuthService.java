// backend/src/main/java/com/nemo/backend/domain/auth/service/AuthService.java
package com.nemo.backend.domain.auth.service;

import com.nemo.backend.domain.auth.dto.*;
import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.domain.auth.token.RefreshToken;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Service
@Transactional
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    public AuthService(UserRepository userRepository,
                       RefreshTokenRepository refreshTokenRepository,
                       PasswordEncoder passwordEncoder,
                       JwtTokenProvider jwtTokenProvider) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    // ===== 회원 가입 =====
    public SignUpResponse signUp(SignUpRequest request) {
        if (request.getEmail() == null || request.getEmail().isBlank()) {
            throw new IllegalArgumentException("이메일은 필수입니다.");
        }
        if (request.getPassword() == null || request.getPassword().isBlank()) {
            throw new IllegalArgumentException("비밀번호는 필수입니다.");
        }
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new IllegalArgumentException("이미 가입된 이메일입니다.");
        }
        // 비밀번호 암호화 후 저장
        User user = User.builder()
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .nickname(request.getNickname())
                .profileImageUrl(null)
                .provider("LOCAL")
                .build();
        User saved = userRepository.save(user);
        return new SignUpResponse(saved.getId(), saved.getEmail(), saved.getNickname(), saved.getProfileImageUrl());
    }

    // ===== 로그인 =====
    public LoginResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new IllegalArgumentException("가입되지 않은 이메일입니다."));
        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new IllegalArgumentException("비밀번호가 일치하지 않습니다.");
        }
        // 액세스 토큰 발급
        String accessToken = jwtTokenProvider.generateAccessToken(user);
        // 리프레시 토큰 발급 (2주간 유효)
        String refreshTokenStr = UUID.randomUUID().toString();
        LocalDateTime expiry = LocalDateTime.now().plusDays(14);
        Optional<RefreshToken> existing = refreshTokenRepository.findFirstByUserId(user.getId());
        RefreshToken tokenEntity = existing.orElseGet(RefreshToken::new);
        tokenEntity.setUserId(user.getId());
        tokenEntity.setToken(refreshTokenStr);
        tokenEntity.setExpiry(expiry);
        refreshTokenRepository.save(tokenEntity);
        return new LoginResponse(user.getId(), user.getEmail(), user.getNickname(), user.getProfileImageUrl(),
                accessToken, refreshTokenStr);
    }

    // ===== 로그아웃 =====
    public void logout(Long userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }

    // ===== 회원 탈퇴 =====
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
        // Refresh 토큰 제거 후 회원 삭제
        refreshTokenRepository.deleteByUserId(userId);
        userRepository.delete(user);
    }
}
