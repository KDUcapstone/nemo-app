package com.nemo.backend.domain.auth.util;

import com.nemo.backend.domain.auth.jwt.JwtUtil;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import io.jsonwebtoken.JwtException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class AuthExtractor {

    private final JwtUtil jwtUtil;
    private final RefreshTokenRepository refreshTokenRepository;

    /**
     * 공통 인증 로직
     * - Authorization 헤더 체크
     * - JwtUtil로 AccessToken 검증 + userId 추출
     * - RefreshToken DB 존재 여부 체크
     */
    public Long extractUserId(String authorizationHeader) {
        if (authorizationHeader == null || authorizationHeader.isBlank()) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }

        try {
            Long userId = jwtUtil.getUserId(authorizationHeader);

            boolean hasRefresh = refreshTokenRepository.findFirstByUserId(userId).isPresent();
            if (!hasRefresh) {
                throw new ApiException(ErrorCode.UNAUTHORIZED);
            }

            return userId;

        } catch (JwtException e) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }
    }
}
