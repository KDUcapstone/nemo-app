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

    // 회원가입
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

        User user = new User();
        user.setEmail(request.getEmail().trim());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setNickname(request.getNickname() != null ? request.getNickname() : "");
        user.setProfileImageUrl("");
        user.setProvider("local");
        user.setSocialId(null);

        User saved = userRepository.save(user);
        return new SignUpResponse(
                saved.getId(),
                saved.getEmail(),
                saved.getNickname(),
                saved.getProfileImageUrl()
        );
    }

    // 로그인
    // AuthService.login()
    // 핵심 부분만 발췌
    public LoginResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new IllegalArgumentException("가입되지 않은 이메일입니다."));
        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new IllegalArgumentException("비밀번호가 일치하지 않습니다.");
        }

        String accessToken = jwtTokenProvider.generateAccessToken(user);
        String refreshTokenStr = java.util.UUID.randomUUID().toString();
        java.time.LocalDateTime expiry = java.time.LocalDateTime.now().plusDays(14);

        RefreshToken token = refreshTokenRepository.findFirstByUserId(user.getId())
                .orElseGet(RefreshToken::new);
        token.setUserId(user.getId());
        token.setToken(refreshTokenStr);
        token.setExpiry(expiry);
        refreshTokenRepository.save(token);

        String nickname = user.getNickname() == null ? "" : user.getNickname();
        String profile = user.getProfileImageUrl() == null ? "" : user.getProfileImageUrl();

        return new LoginResponse(
                user.getId(),          // ✅ 절대 null 아님(없으면 0L로 방어)
                user.getEmail(),
                nickname,
                profile,
                accessToken,
                refreshTokenStr
        );
    }



    // 로그아웃
    public void logout(Long userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }

    // 회원탈퇴 (비밀번호 검증 포함)
    public void deleteAccount(Long userId) {
        deleteAccount(userId, null);
    }
    public void deleteAccount(Long userId, String rawPassword) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("해당 사용자를 찾을 수 없습니다."));

        if (rawPassword == null || rawPassword.isBlank()
                || !passwordEncoder.matches(rawPassword, user.getPassword())) {
            throw new IllegalArgumentException("비밀번호가 일치하지 않습니다.");
        }
        refreshTokenRepository.deleteByUserId(userId);
        userRepository.delete(user);
    }
}
