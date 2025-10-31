package com.nemo.backend.domain.auth.service;

import com.nemo.backend.domain.auth.dto.*;
import com.nemo.backend.domain.auth.token.RefreshToken;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Service layer encapsulating authentication and account lifecycle logic.
 */
@Service
public class AuthService {
    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final JwtTokenProvider jwtTokenProvider;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public AuthService(UserRepository userRepository,
                       RefreshTokenRepository refreshTokenRepository,
                       JwtTokenProvider jwtTokenProvider) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    @Transactional
    public SignUpResponse signUp(SignUpRequest request) {
        userRepository.findByEmail(request.getEmail()).ifPresent(u -> {
            throw new ApiException(ErrorCode.DUPLICATE_EMAIL);
        });
        User user = new User();
        user.setEmail(request.getEmail());
        user.setNickname(request.getNickname());
        user.setProvider("LOCAL");
        if (request.getPassword() != null && !request.getPassword().isEmpty()) {
            user.setPassword(passwordEncoder.encode(request.getPassword()));
        }
        userRepository.save(user);
        return new SignUpResponse(user.getId(), user.getEmail(), user.getNickname(), user.getProfileImageUrl());
    }

    @Transactional
    public LoginResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_CREDENTIALS));
        if (user.getPassword() == null || !passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new ApiException(ErrorCode.INVALID_CREDENTIALS);
        }
        refreshTokenRepository.deleteByUserId(user.getId());
        String accessToken = jwtTokenProvider.generateAccessToken(user);
        String refreshToken = createAndSaveRefreshToken(user.getId());
        return new LoginResponse(user.getId(), user.getEmail(), user.getNickname(), user.getProfileImageUrl(),
                accessToken, refreshToken);
    }

    @Transactional
    public void logout(Long userId) {
        userRepository.findById(userId).orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
        refreshTokenRepository.deleteByUserId(userId);
    }

    @Transactional
    public void deleteAccount(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_ALREADY_DELETED));
        refreshTokenRepository.deleteByUserId(userId);
        userRepository.delete(user);
    }

    // 액세스 만료(초). JwtTokenProvider가 만료 시간을 외부로 안 주면 yml에서 주입.
    @Value("${jwt.access-exp-seconds:3600}")
    private long accessExpSeconds;

    // 리프레시 총 유효기간(일) — 기존 createAndSaveRefreshToken과 동일하게 맞춤
    @Value("${jwt.refresh-exp-days:14}")
    private long refreshExpDays;

    // 리프레시 회전 임계(초) — 남은 시간이 이 값 이하이면 새 리프레시로 교체
    @Value("${jwt.refresh-rotate-threshold-sec:259200}") // 기본 3일
    private long rotateThresholdSec;

    /**
     * 리프레시 토큰으로 새 액세스 토큰을 발급한다.
     * - 전달된 refreshToken이 DB에 있고 만료되지 않았어야 함
     * - 만료 임박(rotateThresholdSec 이하)이면 리프레시도 교체(회전)
     */
    @Transactional
    public RefreshResponse refresh(RefreshRequest request) {
        if (request == null || request.refreshToken() == null || request.refreshToken().isBlank()) {
            throw new ApiException(ErrorCode.UNAUTHORIZED); // 혹은 ErrorCode.INVALID_INPUT
        }

        RefreshToken stored = refreshTokenRepository.findByToken(request.refreshToken())
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED)); // INVALID_REFRESH_TOKEN

        // 만료 체크 (DB 기준)
        LocalDateTime now = LocalDateTime.now();
        if (stored.getExpiry() == null || !stored.getExpiry().isAfter(now)) {
            // 만료/이상 상태면 즉시 폐기
            refreshTokenRepository.deleteByToken(stored.getToken());
            throw new ApiException(ErrorCode.UNAUTHORIZED); // REFRESH_TOKEN_EXPIRED
        }

        // 사용자 확인
        User user = userRepository.findById(stored.getUserId())
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));

        // 1) 새 액세스 토큰 발급
        String newAccess = jwtTokenProvider.generateAccessToken(user);

        // 2) 리프레시 회전 여부 판단 (DB의 expiry 기준)
        long remainSec = Duration.between(now, stored.getExpiry()).getSeconds();
        String outRefresh = stored.getToken();

        if (remainSec <= rotateThresholdSec) {
            // 안전하게 기존 토큰 교체
            outRefresh = rotateRefreshToken(stored);
        }

        return new RefreshResponse(newAccess, outRefresh, accessExpSeconds);
    }

    /** 기존 createAndSaveRefreshToken은 로그인 때만 쓰니 유지하고,
     *  회전은 "해당 엔티티 교체"로 처리하면 DB에 한 줄만 유지됨. */
    private String rotateRefreshToken(RefreshToken entity) {
        String newToken = UUID.randomUUID().toString();
        entity.setToken(newToken);
        entity.setExpiry(LocalDateTime.now().plusDays(refreshExpDays));
        refreshTokenRepository.save(entity);
        return newToken;
    }

    private String createAndSaveRefreshToken(Long userId) {
        String token = UUID.randomUUID().toString();
        RefreshToken refreshToken = new RefreshToken();
        refreshToken.setUserId(userId);
        refreshToken.setToken(token);
        refreshToken.setExpiry(LocalDateTime.now().plusDays(14));
        refreshTokenRepository.save(refreshToken);
        return token;
    }
}