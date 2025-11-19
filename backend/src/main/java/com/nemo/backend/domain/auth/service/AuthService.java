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

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.UUID;

@Service
@Transactional
@RequiredArgsConstructor // ⭐ final 필드만 자동 생성자로 만들기
public class AuthService {

    // ----------------------------------------------------
    // ⭐ 의존성 주입되는 서비스들
    // ----------------------------------------------------
    private final UserRepository userRepository;                 // 사용자 정보 조회/저장
    private final RefreshTokenRepository refreshTokenRepository; // Refresh Token DB 저장소
    private final PasswordEncoder passwordEncoder;               // 비밀번호 암호화
    private final JwtUtil jwtUtil;                               // 🔥 JWT 발급 & 검증 유틸 (고정 키 기반)

    // ----------------------------------------------------
    // ⭐ yml 에서 읽어오는 설정 값들
    // ----------------------------------------------------
    @Value("${jwt.access-exp-seconds:3600}")            // Access Token 유효기간(초)
    private long accessExpSeconds;

    @Value("${jwt.refresh-exp-days:14}")                // Refresh Token 유효기간(일)
    private long refreshExpDays;

    @Value("${jwt.refresh-rotate-threshold-sec:259200}") // Refresh Token 회전 시점(3일)
    private long rotateThresholdSec;

    // ====================================================
    // 1) 회원가입
    // ====================================================
    /**
     * 회원가입 로직
     * - 이메일 중복 체크
     * - 비밀번호 암호화
     * - User 엔티티 생성 후 DB 저장
     */
    public SignUpResponse signUp(SignUpRequest request) {

        // 1) 유효성 검사
        if (request.getEmail() == null || request.getEmail().isBlank()) {
            throw new IllegalArgumentException("이메일은 필수입니다.");
        }
        if (request.getPassword() == null || request.getPassword().isBlank()) {
            throw new IllegalArgumentException("비밀번호는 필수입니다.");
        }
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new IllegalArgumentException("이미 가입된 이메일입니다.");
        }

        // 2) User 엔티티 생성
        User user = new User();
        user.setEmail(request.getEmail().trim());
        user.setPassword(passwordEncoder.encode(request.getPassword())); // 비밀번호 암호화
        user.setNickname(request.getNickname() != null ? request.getNickname() : "");
        user.setProfileImageUrl("");    // 기본값
        user.setProvider("local");      // 회원가입 방식
        user.setSocialId(null);         // 소셜 로그인 X

        // 3) 저장
        User saved = userRepository.save(user);

        // 4) 응답 DTO 반환
        return new SignUpResponse(
                saved.getId(),
                saved.getEmail(),
                saved.getNickname(),
                saved.getProfileImageUrl()
        );
    }

    // ====================================================
    // 2) 로그인
    // ====================================================
    /**
     * 로그인 로직
     * - 이메일/비밀번호 체크
     * - AccessToken 생성(JwtUtil)
     * - RefreshToken DB 저장
     * - LoginResponse(6개 필드) 반환
     */
    public LoginResponse login(LoginRequest request) {

        // 1) 이메일 존재 확인
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new IllegalArgumentException("가입되지 않은 이메일입니다."));

        // 2) 비밀번호 체크
        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new IllegalArgumentException("비밀번호가 일치하지 않습니다.");
        }

        // --------------------------------------------------
        // 🔥 3) AccessToken 발급 → JwtUtil 사용
        // JwtTokenProvider는 제거됨
        // --------------------------------------------------
        String accessToken = jwtUtil.createAccessToken(user.getId(), user.getEmail());

        // --------------------------------------------------
        // ⭐ Refresh Token 저장 로직
        // --------------------------------------------------
        String refreshTokenStr = UUID.randomUUID().toString();
        LocalDateTime expiry = LocalDateTime.now().plusDays(refreshExpDays);

        RefreshToken token = refreshTokenRepository.findFirstByUserId(user.getId())
                .orElseGet(RefreshToken::new); // 없으면 새로 생성

        token.setUserId(user.getId());
        token.setToken(refreshTokenStr);
        token.setExpiry(expiry);
        refreshTokenRepository.save(token);

        // --------------------------------------------------
        // ⭐ LoginResponse는 6개 필드 필요
        // --------------------------------------------------
        String nickname = user.getNickname() == null ? "" : user.getNickname();
        String profile = user.getProfileImageUrl() == null ? "" : user.getProfileImageUrl();

        return new LoginResponse(
                user.getId(),
                user.getEmail(),
                nickname,
                profile,
                accessToken,
                refreshTokenStr
        );
    }

    // ====================================================
    // 3) 로그아웃
    // ====================================================
    public void logout(Long userId) {
        refreshTokenRepository.deleteByUserId(userId); // RefreshToken 삭제
    }

    // ====================================================
    // 4) 회원탈퇴 (비밀번호 검증)
    // ====================================================
    public void deleteAccount(Long userId) {
        deleteAccount(userId, null);
    }

    public void deleteAccount(Long userId, String rawPassword) {

        // 사용자 존재 확인
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("해당 사용자를 찾을 수 없습니다."));

        // 비밀번호 검증
        if (rawPassword == null || rawPassword.isBlank()
                || !passwordEncoder.matches(rawPassword, user.getPassword())) {
            throw new IllegalArgumentException("비밀번호가 일치하지 않습니다.");
        }

        // RefreshToken 제거 + User 제거
        refreshTokenRepository.deleteByUserId(userId);
        userRepository.delete(user);
    }

    // ====================================================
    // 5) Refresh Token으로 Access Token 재발급
    // ====================================================
    /**
     * refresh()
     * - RefreshToken 문자열 → DB 조회
     * - 만료되었으면 예외
     * - AccessToken 재발급
     * - RefreshToken 만료 임박 시 → rotate(교체)
     */
    @Transactional
    public RefreshResponse refresh(RefreshRequest request) {

        if (request == null || request.refreshToken() == null || request.refreshToken().isBlank()) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }

        RefreshToken stored = refreshTokenRepository.findByToken(request.refreshToken())
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));

        LocalDateTime now = LocalDateTime.now();

        // 1) RefreshToken 만료 확인
        if (stored.getExpiry() == null || !stored.getExpiry().isAfter(now)) {
            refreshTokenRepository.deleteByToken(stored.getToken());
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }

        // 2) 사용자 확인
        User user = userRepository.findById(stored.getUserId())
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));

        // --------------------------------------------------
        // 🔥 3) Access Token 재발급 → JwtUtil 사용
        // --------------------------------------------------
        String newAccess = jwtUtil.createAccessToken(user.getId(), user.getEmail());

        // --------------------------------------------------
        // 4) RefreshToken 회전 여부 판단
        // --------------------------------------------------
        long remainSec = Duration.between(now, stored.getExpiry()).getSeconds();
        String outRefresh = stored.getToken();

        if (remainSec <= rotateThresholdSec) {
            // 만료 임박 → 새 RefreshToken 발급
            outRefresh = rotateRefreshToken(stored);
        }

        return new RefreshResponse(newAccess, outRefresh, accessExpSeconds);
    }

    // Refresh Token 회전
    private String rotateRefreshToken(RefreshToken entity) {
        String newToken = UUID.randomUUID().toString();
        entity.setToken(newToken);
        entity.setExpiry(LocalDateTime.now().plusDays(refreshExpDays));
        refreshTokenRepository.save(entity);
        return newToken;
    }

    // (예비) RefreshToken 생성 편의 메서드
    private String createAndSaveRefreshToken(Long userId) {
        String token = UUID.randomUUID().toString();
        RefreshToken refreshToken = new RefreshToken();
        refreshToken.setUserId(userId);
        refreshToken.setToken(token);
        refreshToken.setExpiry(LocalDateTime.now().plusDays(refreshExpDays));
        refreshTokenRepository.save(refreshToken);
        return token;
    }
}
