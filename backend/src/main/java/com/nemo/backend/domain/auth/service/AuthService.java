package com.nemo.backend.domain.auth.service;

import com.nemo.backend.domain.auth.dto.*;
import com.nemo.backend.domain.auth.jwt.JwtUtil;
import com.nemo.backend.domain.auth.token.RefreshToken;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@Transactional
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    @Value("${jwt.access-exp-seconds:3600}")
    private long accessExpSeconds;

    @Value("${jwt.refresh-exp-days:14}")
    private long refreshExpDays;

    @Value("${jwt.refresh-rotate-threshold-sec:259200}")
    private long rotateThresholdSec;

    // =======================
    // 1) 회원가입
    // =======================
    public SignUpResponse signUp(SignUpRequest request) {

        if (request == null
                || request.getEmail() == null || request.getEmail().isBlank()
                || request.getPassword() == null || request.getPassword().isBlank()
                || request.getNickname() == null || request.getNickname().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "필수 정보가 누락되었습니다. (email, password, nickname)");
        }

        String email = request.getEmail().trim();

        if (userRepository.existsByEmail(email)) {
            throw new ApiException(ErrorCode.DUPLICATE_EMAIL);
        }

        User user = new User();
        user.setEmail(email);
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setNickname(request.getNickname().trim());  // ★ 필수
        user.setProfileImageUrl(request.getProfileImageUrl() != null ? request.getProfileImageUrl() : "");
        user.setProvider("local");
        user.setSocialId(null);

        User saved = userRepository.save(user);

        String createdAtStr = (saved.getCreatedAt() != null)
                ? saved.getCreatedAt().toString()
                : "";

        return new SignUpResponse(
                saved.getId(),
                saved.getEmail(),
                saved.getNickname(),
                saved.getProfileImageUrl(),
                createdAtStr
        );
    }


    // =======================
    // 2) 로그인
    // =======================
    public LoginResponse login(LoginRequest request) {

        if (request == null
                || request.getEmail() == null || request.getEmail().isBlank()
                || request.getPassword() == null || request.getPassword().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST);
        }

        User user = userRepository.findByEmail(request.getEmail().trim())
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_CREDENTIALS));

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new ApiException(ErrorCode.INVALID_CREDENTIALS);
        }

        String accessToken = jwtUtil.createAccessToken(user.getId(), user.getEmail());
        String refreshTokenStr = upsertRefreshTokenForUser(user.getId());

        String nickname = user.getNickname() != null ? user.getNickname() : "";
        String profile = user.getProfileImageUrl() != null ? user.getProfileImageUrl() : "";

        return new LoginResponse(
                accessToken,
                refreshTokenStr,
                accessExpSeconds,
                user.getId(),
                nickname,
                profile
        );
    }

    // =======================
    // 3) 로그아웃 (명세 반영)
    // =======================
    public void logout(Long userId, String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "refreshToken 은 필수입니다.");
        }

        RefreshToken stored = refreshTokenRepository.findByToken(refreshToken)
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_TOKEN));

        // 다른 유저의 토큰이면 무효
        if (!stored.getUserId().equals(userId)) {
            throw new ApiException(ErrorCode.INVALID_TOKEN);
        }

        LocalDateTime now = LocalDateTime.now();

        // 만료된 토큰이면 삭제 후 에러
        if (stored.getExpiry() == null || !stored.getExpiry().isAfter(now)) {
            refreshTokenRepository.delete(stored);
            throw new ApiException(ErrorCode.INVALID_TOKEN);
        }

        // 정상 토큰이면 해당 토큰만 삭제
        refreshTokenRepository.delete(stored);
    }

    /**
     * (기존 코드 사용 중이면 유지용 – 전체 토큰 삭제)
     */
    public void logoutAll(Long userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }

    // =======================
    // 4) 회원탈퇴 (비밀번호 확인 방식)
    // =======================
    public void deleteAccount(Long userId, String rawPassword) {

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));

        if (rawPassword != null && !rawPassword.isBlank()) {
            if (!passwordEncoder.matches(rawPassword, user.getPassword())) {
                throw new ApiException(ErrorCode.INVALID_PASSWORD);
            }
        }

        refreshTokenRepository.deleteByUserId(userId);
        userRepository.delete(user);
    }

    public void deleteAccount(Long userId) {
        deleteAccount(userId, null);
    }

    // =======================
    // 5) Access Token 재발급
    // =======================
    @Transactional(readOnly = true)
    public RefreshResponse refresh(RefreshRequest request) {

        if (request == null
                || request.refreshToken() == null
                || request.refreshToken().isBlank()) {
            // 400 TOKEN_REQUIRED
            throw new ApiException(ErrorCode.TOKEN_REQUIRED);
        }

        RefreshToken stored = refreshTokenRepository.findByToken(request.refreshToken())
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_TOKEN));

        LocalDateTime now = LocalDateTime.now();

        // 만료 or 잘못된 토큰
        if (stored.getExpiry() == null || !stored.getExpiry().isAfter(now)) {
            refreshTokenRepository.delete(stored);
            throw new ApiException(ErrorCode.INVALID_TOKEN);
        }

        User user = userRepository.findById(stored.getUserId())
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));

        // 새 액세스 토큰 발급
        String newAccessToken = jwtUtil.createAccessToken(user.getId(), user.getEmail());

        // refreshToken 갱신 정책 (만료 임박 시 새로 발급)
        LocalDateTime expiry = stored.getExpiry();
        long totalSeconds = refreshExpDays * 24L * 60L * 60L;
        long remainingSeconds = java.time.Duration.between(now, expiry).getSeconds();

        String newRefreshToken = null;

        // 남은 시간이 전체의 1/3 이하라면 새 토큰 발급
        if (remainingSeconds < totalSeconds / 3) {
            String rotated = UUID.randomUUID().toString();
            stored.setToken(rotated);
            stored.setExpiry(now.plusDays(refreshExpDays));
            refreshTokenRepository.save(stored);
            newRefreshToken = rotated;
        }

        // 명세: refreshToken은 갱신된 경우만 포함
        return new RefreshResponse(newAccessToken, newRefreshToken);
    }

    // =======================
    // 내부 유틸: RefreshToken upsert
    // =======================
    private String upsertRefreshTokenForUser(Long userId) {

        LocalDateTime newExpiry = LocalDateTime.now().plusDays(refreshExpDays);

        return refreshTokenRepository.findFirstByUserId(userId)
                .map(entity -> {
                    entity.setToken(UUID.randomUUID().toString());
                    entity.setExpiry(newExpiry);
                    return entity.getToken();
                })
                .orElseGet(() -> {
                    RefreshToken refreshToken = new RefreshToken();
                    refreshToken.setUserId(userId);
                    refreshToken.setToken(UUID.randomUUID().toString());
                    refreshToken.setExpiry(newExpiry);
                    refreshTokenRepository.save(refreshToken);
                    return refreshToken.getToken();
                });
    }
}