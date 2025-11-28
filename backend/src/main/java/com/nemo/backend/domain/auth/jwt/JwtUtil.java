// domain/auth/jwt/JwtUtil.java
package com.nemo.backend.domain.auth.jwt;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * JwtUtil
 * ---------------------------------------------------------
 * - JWT 토큰을 "발급"도 하고, "검증"도 하는 유틸 클래스.
 * - 랜덤 키를 쓰지 않고, yml(환경설정)에 적어둔 비밀키를 사용한다.
 *
 * 💡 핵심 개념
 *   - AccessToken : 짧게(예: 30분) 쓰고 버리는 토큰 → 매 요청 인증용
 *   - RefreshToken: 길게(예: 14일) 보관하는 토큰 → AccessToken 재발급용
 *
 *   이 클래스는 두 종류 토큰의 공통 부분(서명, 클레임, 파싱)을 담당한다.
 * ---------------------------------------------------------
 */
@Component
public class JwtUtil {

    /** 클레임 키 이름: userId */
    public static final String CLAIM_USER_ID = "userId";

    /** 클레임 키 이름: email */
    public static final String CLAIM_EMAIL   = "email";

    /** HS256 서명에 사용할 비밀키 (환경설정에서 읽어와서 한번만 생성) */
    private final SecretKey key;

    /** 토큰 발급자(issuer) 값, 예: "nemo-backend" */
    private final String issuer;

    /** Access Token 유효 시간 (밀리초 단위) */
    private final long accessTtlMs;

    /** 서버/클라이언트 시간차 허용 범위 (초 단위) – 여기선 3분 */
    private static final long CLOCK_SKEW_SECONDS = 180L; // 180초 = 3분

    /**
     * 생성자
     * - application.yml(or .env)에 있는 설정 값을 주입받는다.
     */
    public JwtUtil(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.issuer}") String issuer,
            @Value("${app.jwt.access-ttl-ms}") long accessTtlMs
    ) {
        // ✅ 비밀키는 최소 32바이트 이상이어야 HS256에 안전하게 사용 가능
        if (secret == null || secret.length() < 32) {
            throw new IllegalArgumentException(
                    "app.jwt.secret 는 32자 이상으로 설정해야 합니다. (현재 길이: " +
                            (secret == null ? 0 : secret.length()) + ")"
            );
        }

        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.issuer = issuer;
        this.accessTtlMs = accessTtlMs;
    }

    // =====================================================================
    // ✅ 토큰 발급 부분
    // =====================================================================

    /**
     * 공통 토큰 생성 로직
     *
     * @param userId  토큰에 넣을 사용자 ID
     * @param email   토큰에 넣을 사용자 이메일
     * @param ttlMs   토큰 유효 시간(밀리초)
     * @return        서명까지 완료된 JWT 문자열("x.y.z" 형태)
     */
    private String buildToken(Long userId, String email, long ttlMs) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + ttlMs);

        return Jwts.builder()
                // 누가(어떤 서버)가 만든 토큰인지
                .setIssuer(issuer)
                // 언제 만들었는지
                .setIssuedAt(now)
                // 언제 만료되는지
                .setExpiration(expiry)
                // 토큰의 "주체" (필요 시 userId 넣을 수도 있음)
                .setSubject(String.valueOf(userId))

                // 우리가 추가로 넣고 싶은 정보(클레임)
                .claim(CLAIM_USER_ID, userId)
                .claim(CLAIM_EMAIL, email)

                // 마지막으로 비밀키로 서명
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();
    }

    /** Access Token 생성 (예: 30분 유효) */
    public String createAccessToken(Long userId, String email) {
        return buildToken(userId, email, accessTtlMs);
    }

    // =====================================================================
    // ✅ 토큰 파싱 / 검증 부분
    // =====================================================================

    /**
     * "Authorization 헤더" or "raw 토큰 문자열" 둘 다에서
     * 실제 토큰 부분만 꺼내는 메서드.
     *
     * 예)
     *   - "Bearer abc.def.ghi"  → "abc.def.ghi"
     *   - "abc.def.ghi"         → 그대로 사용
     */
    private String resolveToken(String value) {
        if (value == null) {
            throw new JwtException("Token is null");
        }

        String v = value.trim();
        if (v.startsWith("Bearer ")) {
            // "Bearer " 이후의 실제 토큰 부분만 추출
            return v.substring(7).trim();
        }
        return v;
    }

    /**
     * 토큰에서 Claims(내용물) 꺼내기
     * - 시그니처 검증 + 만료 시간 체크까지 같이 수행됨.
     *
     * @param authorizationOrToken  "Bearer xxx" 또는 "xxx.yyy.zzz"
     * @return                      파싱된 Claims
     * @throws ExpiredJwtException  만료된 토큰일 경우(필요하면 따로 캐치해서 처리 가능)
     * @throws JwtException         그 외 서명 오류, 구조 오류 등
     */
    private Claims parseClaims(String authorizationOrToken) {
        String token = resolveToken(authorizationOrToken);

        try {
            return Jwts.parserBuilder()
                    .setSigningKey(key)     // 서명 검증용 키
                    .requireIssuer(issuer)  // issuer(발급자)도 일치하는지 체크
                    .setAllowedClockSkewSeconds(CLOCK_SKEW_SECONDS) // 🔥 시간 오차 허용
                    .build()
                    .parseClaimsJws(token)  // 여기서 서명 검증 + 만료 검사
                    .getBody();
        } catch (ExpiredJwtException e) {
            // 만료된 토큰은 따로 처리하고 싶으면 밖에서 잡아서 사용
            throw e;
        } catch (JwtException e) {
            // 서명 불일치, 잘못된 포맷 등
            throw e;
        } catch (IllegalArgumentException e) {
            throw new JwtException("Invalid JWT token", e);
        }
    }

    /**
     * 토큰이 만료되었는지 여부만 간단히 확인하고 싶을 때 사용
     */
    public boolean isExpired(String authorizationOrToken) {
        Claims claims = parseClaims(authorizationOrToken);
        Date exp = claims.getExpiration();
        return exp != null && exp.before(new Date());
    }

    /**
     * 토큰이 정상적인지(서명 OK, issuer OK, 만료 X)만 체크할 때
     * - 예: SecurityFilter에서 try/catch로 감싸서 사용
     */
    public void validateToken(String authorizationOrToken) {
        parseClaims(authorizationOrToken); // 문제가 있으면 예외 던짐
    }

    // =====================================================================
    // ✅ 토큰에서 정보 꺼내기
    // =====================================================================

    /** userId(Long) 추출 */
    public Long getUserId(String authorizationOrToken) {
        Object v = parseClaims(authorizationOrToken).get(CLAIM_USER_ID);
        if (v == null) throw new JwtException("Missing claim: userId");

        // JJWT가 숫자를 Integer/Long 등으로 줄 수 있어서 타입 방어 코드 추가
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
