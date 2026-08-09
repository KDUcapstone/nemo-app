package com.nemo.backend.domain.auth.jwt;

import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * JwtUtil 계약 테스트.
 *
 * <p>발급된 토큰이 되돌아왔을 때 무엇을 신뢰할 수 있고 무엇을 거절해야 하는지를 고정한다.
 * Spring 컨텍스트를 띄우지 않고 생성자로 직접 설정을 주입하므로, TTL이나 issuer를
 * 케이스마다 다르게 줄 수 있다.
 */
class JwtUtilTest {

    private static final String SECRET = "test-secret-key-for-jwt-unit-tests-32bytes-min";
    private static final String OTHER_SECRET = "another-secret-key-that-is-also-long-enough-32";
    private static final String ISSUER = "nemo-backend";
    private static final long ONE_HOUR_MS = 3_600_000L;

    /** 3분 클럭 스큐 허용을 확실히 넘기기 위한 만료 폭. */
    private static final long EXPIRED_BEYOND_SKEW_MS = -300_000L;

    private static final Long USER_ID = 42L;
    private static final String EMAIL = "nemo@example.com";

    private JwtUtil jwtUtil(String secret, String issuer, long ttlMs) {
        return new JwtUtil(secret, issuer, ttlMs);
    }

    private JwtUtil defaultJwtUtil() {
        return jwtUtil(SECRET, ISSUER, ONE_HOUR_MS);
    }

    @Nested
    @DisplayName("설정 검증")
    class Configuration {

        @Test
        @DisplayName("secret이 32자 미만이면 생성 시점에 거절한다")
        void rejectsShortSecret() {
            assertThatThrownBy(() -> jwtUtil("too-short", ISSUER, ONE_HOUR_MS))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("32자 이상");
        }

        @Test
        @DisplayName("secret이 null이면 거절한다")
        void rejectsNullSecret() {
            assertThatThrownBy(() -> jwtUtil(null, ISSUER, ONE_HOUR_MS))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Nested
    @DisplayName("정상 발급·검증")
    class HappyPath {

        @Test
        @DisplayName("발급한 토큰에서 userId와 email을 그대로 되찾는다")
        void roundTripsClaims() {
            JwtUtil sut = defaultJwtUtil();

            String token = sut.createAccessToken(USER_ID, EMAIL);

            assertThat(sut.getUserId(token)).isEqualTo(USER_ID);
            assertThat(sut.getEmail(token)).isEqualTo(EMAIL);
        }

        @Test
        @DisplayName("Bearer 접두사가 붙은 Authorization 헤더도 그대로 처리한다")
        void acceptsBearerPrefixedHeader() {
            JwtUtil sut = defaultJwtUtil();

            String header = "Bearer " + sut.createAccessToken(USER_ID, EMAIL);

            assertThat(sut.getUserId(header)).isEqualTo(USER_ID);
        }

        @Test
        @DisplayName("앞뒤 공백이 섞인 헤더도 처리한다")
        void trimsWhitespace() {
            JwtUtil sut = defaultJwtUtil();

            String header = "  Bearer   " + sut.createAccessToken(USER_ID, EMAIL) + "  ";

            assertThat(sut.getUserId(header)).isEqualTo(USER_ID);
        }

        @Test
        @DisplayName("email 클레임이 없는 토큰은 null을 반환한다 (예외가 아니다)")
        void missingEmailClaimReturnsNull() {
            JwtUtil sut = defaultJwtUtil();

            String token = signedToken(SECRET, ISSUER, USER_ID, null, ONE_HOUR_MS);

            assertThat(sut.getEmail(token)).isNull();
        }

        @Test
        @DisplayName("validateToken은 정상 토큰에서 예외를 던지지 않는다")
        void validateTokenPassesForValidToken() {
            JwtUtil sut = defaultJwtUtil();

            String token = sut.createAccessToken(USER_ID, EMAIL);

            assertThatCode(() -> sut.validateToken(token)).doesNotThrowAnyException();
        }
    }

    @Nested
    @DisplayName("거절해야 하는 토큰")
    class Rejection {

        @Test
        @DisplayName("다른 키로 서명된 토큰은 거절한다")
        void rejectsForeignSignature() {
            JwtUtil sut = defaultJwtUtil();

            String forged = signedToken(OTHER_SECRET, ISSUER, USER_ID, EMAIL, ONE_HOUR_MS);

            assertThatThrownBy(() -> sut.validateToken(forged))
                    .isInstanceOf(JwtException.class);
        }

        @Test
        @DisplayName("issuer가 다른 토큰은 서명이 맞아도 거절한다")
        void rejectsForeignIssuer() {
            JwtUtil sut = defaultJwtUtil();

            String otherIssuer = signedToken(SECRET, "someone-else", USER_ID, EMAIL, ONE_HOUR_MS);

            assertThatThrownBy(() -> sut.validateToken(otherIssuer))
                    .isInstanceOf(JwtException.class);
        }

        @Test
        @DisplayName("만료된 토큰은 거절한다")
        void rejectsExpiredToken() {
            JwtUtil sut = jwtUtil(SECRET, ISSUER, EXPIRED_BEYOND_SKEW_MS);

            String expired = sut.createAccessToken(USER_ID, EMAIL);

            assertThatThrownBy(() -> sut.validateToken(expired))
                    .isInstanceOf(ExpiredJwtException.class);
        }

        @Test
        @DisplayName("구조가 깨진 문자열은 거절한다")
        void rejectsMalformedToken() {
            JwtUtil sut = defaultJwtUtil();

            assertThatThrownBy(() -> sut.validateToken("not-a-jwt"))
                    .isInstanceOf(JwtException.class);
        }

        @Test
        @DisplayName("빈 문자열은 거절한다")
        void rejectsEmptyToken() {
            JwtUtil sut = defaultJwtUtil();

            assertThatThrownBy(() -> sut.validateToken(""))
                    .isInstanceOf(JwtException.class);
        }

        @Test
        @DisplayName("null은 거절한다")
        void rejectsNullToken() {
            JwtUtil sut = defaultJwtUtil();

            assertThatThrownBy(() -> sut.validateToken(null))
                    .isInstanceOf(JwtException.class)
                    .hasMessageContaining("null");
        }

        @Test
        @DisplayName("userId 클레임이 없으면 거절한다")
        void rejectsTokenWithoutUserId() {
            JwtUtil sut = defaultJwtUtil();

            String token = Jwts.builder()
                    .setIssuer(ISSUER)
                    .setIssuedAt(new Date())
                    .setExpiration(new Date(System.currentTimeMillis() + ONE_HOUR_MS))
                    .signWith(hmacKey(SECRET), SignatureAlgorithm.HS256)
                    .compact();

            assertThatThrownBy(() -> sut.getUserId(token))
                    .isInstanceOf(JwtException.class)
                    .hasMessageContaining("userId");
        }

        @Test
        @DisplayName("userId 클레임이 숫자가 아니면 거절한다")
        void rejectsNonNumericUserId() {
            JwtUtil sut = defaultJwtUtil();

            String token = Jwts.builder()
                    .setIssuer(ISSUER)
                    .setIssuedAt(new Date())
                    .setExpiration(new Date(System.currentTimeMillis() + ONE_HOUR_MS))
                    .claim(JwtUtil.CLAIM_USER_ID, "not-a-number")
                    .signWith(hmacKey(SECRET), SignatureAlgorithm.HS256)
                    .compact();

            assertThatThrownBy(() -> sut.getUserId(token))
                    .isInstanceOf(JwtException.class)
                    .hasMessageContaining("Invalid userId claim format");
        }
    }

    @Nested
    @DisplayName("경계 조건")
    class Boundaries {

        @Test
        @DisplayName("만료된 지 3분 이내인 토큰은 클럭 스큐 허용치 안이라 통과한다")
        void acceptsTokenWithinClockSkew() {
            // 서버 간 시계 오차를 흡수하려고 JwtUtil이 180초를 허용한다.
            // 이 관용이 실재한다는 사실 자체를 고정해 둔다 — 줄이거나 없애면 이 테스트가 깨진다.
            JwtUtil sut = jwtUtil(SECRET, ISSUER, -60_000L);

            String justExpired = sut.createAccessToken(USER_ID, EMAIL);

            assertThatCode(() -> sut.validateToken(justExpired)).doesNotThrowAnyException();
        }

        @Test
        @DisplayName("JJWT가 userId를 Integer로 역직렬화해도 Long으로 돌려준다")
        void narrowsIntegerClaimToLong() {
            // 작은 수는 JSON 파서가 Integer로 만든다. getUserId가 이를 흡수하지 못하면
            // ClassCastException이 런타임에 터진다.
            JwtUtil sut = defaultJwtUtil();

            String token = signedToken(SECRET, ISSUER, 7L, EMAIL, ONE_HOUR_MS);

            assertThat(sut.getUserId(token)).isEqualTo(7L);
        }

        @Test
        @DisplayName("isExpired는 만료 토큰에서 false를 반환하지 않고 예외를 던진다")
        void isExpiredThrowsInsteadOfReturningTrue() {
            // 이름은 boolean 질의처럼 보이지만 내부에서 parseClaims를 거치므로
            // 만료 토큰은 값이 아니라 예외로 돌아온다. 호출부는 반환값이 아니라
            // try/catch로 다뤄야 한다 — 실제 동작을 문서로 고정한다.
            JwtUtil sut = jwtUtil(SECRET, ISSUER, EXPIRED_BEYOND_SKEW_MS);

            String expired = sut.createAccessToken(USER_ID, EMAIL);

            assertThatThrownBy(() -> sut.isExpired(expired))
                    .isInstanceOf(ExpiredJwtException.class);
        }

        @Test
        @DisplayName("isExpired는 유효한 토큰에서 false를 반환한다")
        void isExpiredReturnsFalseForValidToken() {
            JwtUtil sut = defaultJwtUtil();

            assertThat(sut.isExpired(sut.createAccessToken(USER_ID, EMAIL))).isFalse();
        }
    }

    // ---------------------------------------------------------------
    // 테스트 픽스처: JwtUtil을 거치지 않고 임의 조건의 토큰을 직접 만든다
    // ---------------------------------------------------------------

    private static SecretKey hmacKey(String secret) {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    private static String signedToken(String secret, String issuer, Long userId, String email, long ttlMs) {
        Date now = new Date();
        var builder = Jwts.builder()
                .setIssuer(issuer)
                .setIssuedAt(now)
                .setExpiration(new Date(now.getTime() + ttlMs))
                .setSubject(String.valueOf(userId))
                .claim(JwtUtil.CLAIM_USER_ID, userId);

        if (email != null) {
            builder.claim(JwtUtil.CLAIM_EMAIL, email);
        }

        return builder.signWith(hmacKey(secret), SignatureAlgorithm.HS256).compact();
    }
}
