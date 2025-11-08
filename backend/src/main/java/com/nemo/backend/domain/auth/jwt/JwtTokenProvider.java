// backend/src/main/java/com/nemo/backend/domain/auth/jwt/JwtTokenProvider.java
package com.nemo.backend.domain.auth.jwt;

import com.nemo.backend.domain.user.entity.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;

import jakarta.annotation.PostConstruct;
import jakarta.servlet.http.HttpServletRequest;
import java.security.Key;
import java.util.Date;

/**
 * Utility for creating and validating JWT access tokens.
 * Access token encodes the user id as the subject claim and expires after a fixed duration.
 */
@Component
public class JwtTokenProvider {
    private static final long ACCESS_TOKEN_VALIDITY_MS = 30 * 60 * 1000L;
    private Key key;

    @PostConstruct
    public void init() {
        this.key = Keys.secretKeyFor(SignatureAlgorithm.HS256);
    }

    public String generateAccessToken(User user) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + ACCESS_TOKEN_VALIDITY_MS);
        return Jwts.builder()
                .setSubject(String.valueOf(user.getId()))
                .setIssuedAt(now)
                .setExpiration(expiry)
                .signWith(key)
                .compact();
    }

    public Long getUserId(String token) {
        Claims claims = Jwts.parserBuilder().setSigningKey(key).build()
                .parseClaimsJws(token).getBody();
        return Long.parseLong(claims.getSubject());
    }

    public boolean validateToken(String token) {
        try {
            Jwts.parserBuilder().setSigningKey(key).build().parseClaimsJws(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * ✅ 추가: Authorization 헤더에서 Bearer 토큰을 추출한다.
     * 헤더가 없거나 Bearer 접두사가 없으면 null 반환.
     */
    // JwtTokenProvider.java 안에 존재해야 함
    public String resolveToken(HttpServletRequest request) {
        String auth = request.getHeader("Authorization");
        if (auth == null || !auth.startsWith("Bearer ")) return null;
        return auth.substring(7);
    }

}
