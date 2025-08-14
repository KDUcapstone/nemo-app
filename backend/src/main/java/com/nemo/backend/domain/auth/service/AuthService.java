package com.nemo.backend.domain.auth.service;

import com.nemo.backend.domain.auth.dto.LoginRequest;
import com.nemo.backend.domain.auth.dto.LoginResponse;
import com.nemo.backend.domain.auth.dto.SignUpRequest;
import com.nemo.backend.domain.auth.dto.SignUpResponse;
import com.nemo.backend.domain.auth.token.RefreshToken;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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