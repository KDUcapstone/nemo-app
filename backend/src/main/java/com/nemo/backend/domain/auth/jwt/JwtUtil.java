// domain/auth/jwt/JwtUtil.java
package com.nemo.backend.domain.auth.jwt;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Date;

/**
 * JwtUtil
 * - 같은 키로 "발급"도 하고 "검증"도 하는 유틸.
 * - Authorization 헤더("Bearer x.y.z")와 raw 토큰 둘 다 지원.
 * - userId, email 같은 커스텀 클레임을 쉽게 꺼낼 수 있음.
 */
@Component
public class JwtUtil {

    // 클레임 키 상수
    public static final String CLAIM_USER_ID = "userId";
    public static final String CLAIM_EMAIL   = "email";

    // yml에서 주입되는 값들
    private final SecretKey key;     // HS256 서명에 쓸 비밀키
    private final String issuer;     // 발급자(iss)
    private final long accessTtlMs;  // 액세스 토큰 만료(ms)

    // 서버/클라 시계 오차 허용 (예: 5초)
    private static final long ALLOWED_CLOCK_SKEW_SECONDS = Duration.ofSeconds(5).toSeconds();

    public JwtUtil(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.issuer}") String issuer,
            @Value("${app.jwt.access-ttl-ms}") long accessTtlMs
    ) {
        // 비밀키(32바이트 이상 권장). 발급/검증 모두 이 키로 진행.
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.issuer = issuer;
        this.accessTtlMs = accessTtlMs;
    }

    /* ========================= 발급 ========================= */

    /**
     * 액세스 토큰 발급 (HS256)
     * - 기본 클레임: iss, iat, exp
     * - 커스텀 클레임: userId, email
     */
    public String createAccessToken(Long userId, String email) {
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .setIssuer(issuer)
                .setIssuedAt(new Date(now))
                .setExpiration(new Date(now + accessTtlMs))
                .claim(CLAIM_USER_ID, userId)
                .claim(CLAIM_EMAIL,   email)
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();
    }

    /* ========================= 검증/파싱 ========================= */

    /** Authorization 헤더나 raw 토큰을 받아 Claims 반환 */
    private Claims parseClaims(String authorizationOrToken) {
        if (authorizationOrToken == null || authorizationOrToken.isBlank()) {
            throw new JwtException("Authorization header or token is missing");
        }
        String token = stripBearer(authorizationOrToken);

        try {
            return Jwts.parserBuilder()
                    .setSigningKey(key)
                    .setAllowedClockSkewSeconds(ALLOWED_CLOCK_SKEW_SECONDS)
                    .build()
                    .parseClaimsJws(token)
                    .getBody();
        } catch (ExpiredJwtException e) {
            throw new JwtException("Token expired", e);
        } catch (UnsupportedJwtException e) {
            throw new JwtException("Unsupported JWT", e);
        } catch (MalformedJwtException e) {
            throw new JwtException("Malformed JWT", e);
        } catch (SecurityException e) { // 서명 불일치
            throw new JwtException("Invalid signature", e);
        } catch (IllegalArgumentException e) {
            throw new JwtException("Invalid token", e);
        }
    }

    /** "Bearer x.y.z" → "x.y.z" 로 변환 (raw 토큰이면 그대로 반환) */
    public String stripBearer(String authorizationOrToken) {
        String v = authorizationOrToken.trim();
        if (v.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return v.substring(7).trim();
        }
        return v;
    }

    /** userId(Long) 추출 */
    public Long getUserId(String authorizationOrToken) {
        Object v = parseClaims(authorizationOrToken).get(CLAIM_USER_ID);
        if (v == null) throw new JwtException("Missing claim: userId");
        if (v instanceof Integer i) return i.longValue();
        if (v instanceof Long l)    return l;
        try {
            return Long.valueOf(String.valueOf(v));
        } catch (NumberFormatException e) {
            throw new JwtException("Invalid userId claim format", e);
        }
    }

    /** email(String) 추출 (없으면 null) */
    public String getEmail(String authorizationOrToken) {
        Object v = parseClaims(authorizationOrToken).get(CLAIM_EMAIL);
        return v == null ? null : String.valueOf(v);
    }
}
