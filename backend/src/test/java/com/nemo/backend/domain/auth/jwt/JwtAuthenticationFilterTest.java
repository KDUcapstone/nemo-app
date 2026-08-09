package com.nemo.backend.domain.auth.jwt;

import com.nemo.backend.domain.auth.principal.UserPrincipal;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * JwtAuthenticationFilter의 요청 단위 계약 테스트.
 *
 * <p>어떤 경로가 토큰 없이 열려 있고, 보호 경로가 어떤 토큰을 401로 막는지를 고정한다.
 * 공개 경로 목록이 필터 안에 하드코딩돼 있어, 누군가 경로를 추가·삭제하면 여기서 깨진다.
 */
class JwtAuthenticationFilterTest {

    private static final String SECRET = "test-secret-key-for-jwt-unit-tests-32bytes-min";
    private static final String OTHER_SECRET = "another-secret-key-that-is-also-long-enough-32";
    private static final String ISSUER = "nemo-backend";
    private static final long ONE_HOUR_MS = 3_600_000L;
    private static final long EXPIRED_BEYOND_SKEW_MS = -300_000L;

    private static final Long USER_ID = 42L;
    private static final String EMAIL = "nemo@example.com";

    private JwtUtil jwtUtil;
    private JwtAuthenticationFilter filter;

    @BeforeEach
    void setUp() {
        jwtUtil = new JwtUtil(SECRET, ISSUER, ONE_HOUR_MS);
        filter = new JwtAuthenticationFilter(jwtUtil);
        SecurityContextHolder.clearContext();
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @ParameterizedTest(name = "공개 경로 {0}은 토큰 없이 통과한다")
    @ValueSource(strings = {
            "/api/users/signup",
            "/api/users/login",
            "/api/auth/logout",
            "/api/auth/oauth/kakao",
            "/api/auth/email/verification/send",
            "/api/auth/password/reset",
            "/api/auth/refresh",
            "/actuator/health",
            "/swagger-ui/index.html",
            "/v3/api-docs/swagger-config",
            "/files/photo.jpg"
    })
    void publicPathsPassWithoutToken(String uri) throws Exception {
        MockFilterChain chain = new MockFilterChain();
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(get(uri), response, chain);

        assertThat(chain.getRequest()).as("체인이 이어져야 한다").isNotNull();
        assertThat(response.getStatus()).isEqualTo(HttpServletResponse.SC_OK);
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
    }

    @Test
    @DisplayName("보호 경로에 Authorization 헤더가 없으면 401과 JSON 오류를 반환하고 체인을 끊는다")
    void protectedPathWithoutHeaderIsUnauthorized() throws Exception {
        MockFilterChain chain = new MockFilterChain();
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(get("/api/photos"), response, chain);

        assertThat(response.getStatus()).isEqualTo(HttpServletResponse.SC_UNAUTHORIZED);
        assertThat(response.getContentAsString()).contains("UNAUTHORIZED");
        assertThat(response.getContentType()).contains("application/json");
        assertThat(chain.getRequest()).as("체인이 끊겨야 한다").isNull();
    }

    @Test
    @DisplayName("보호 경로에 유효한 토큰을 주면 SecurityContext에 userId가 실린다")
    void validTokenPopulatesSecurityContext() throws Exception {
        MockFilterChain chain = new MockFilterChain();
        MockHttpServletResponse response = new MockHttpServletResponse();

        MockHttpServletRequest request = get("/api/photos");
        request.addHeader("Authorization", "Bearer " + jwtUtil.createAccessToken(USER_ID, EMAIL));

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(HttpServletResponse.SC_OK);
        assertThat(chain.getRequest()).isNotNull();

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        assertThat(authentication).isNotNull();
        assertThat(authentication.getPrincipal()).isInstanceOf(UserPrincipal.class);
        assertThat(((UserPrincipal) authentication.getPrincipal()).getId()).isEqualTo(USER_ID);
    }

    @Test
    @DisplayName("다른 키로 서명된 토큰은 401로 막는다")
    void forgedSignatureIsUnauthorized() throws Exception {
        JwtUtil attacker = new JwtUtil(OTHER_SECRET, ISSUER, ONE_HOUR_MS);

        MockFilterChain chain = new MockFilterChain();
        MockHttpServletResponse response = new MockHttpServletResponse();

        MockHttpServletRequest request = get("/api/photos");
        request.addHeader("Authorization", "Bearer " + attacker.createAccessToken(USER_ID, EMAIL));

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(HttpServletResponse.SC_UNAUTHORIZED);
        assertThat(chain.getRequest()).isNull();
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
    }

    @Test
    @DisplayName("만료된 토큰은 401로 막는다")
    void expiredTokenIsUnauthorized() throws Exception {
        JwtUtil expiring = new JwtUtil(SECRET, ISSUER, EXPIRED_BEYOND_SKEW_MS);

        MockFilterChain chain = new MockFilterChain();
        MockHttpServletResponse response = new MockHttpServletResponse();

        MockHttpServletRequest request = get("/api/photos");
        request.addHeader("Authorization", "Bearer " + expiring.createAccessToken(USER_ID, EMAIL));

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(HttpServletResponse.SC_UNAUTHORIZED);
        assertThat(chain.getRequest()).isNull();
    }

    @Test
    @DisplayName("Bearer 접두사가 없는 raw 토큰도 허용한다")
    void rawTokenWithoutBearerPrefixIsAccepted() throws Exception {
        MockFilterChain chain = new MockFilterChain();
        MockHttpServletResponse response = new MockHttpServletResponse();

        MockHttpServletRequest request = get("/api/photos");
        request.addHeader("Authorization", jwtUtil.createAccessToken(USER_ID, EMAIL));

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(HttpServletResponse.SC_OK);
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNotNull();
    }

    @Test
    @DisplayName("이미 인증된 컨텍스트가 있으면 토큰을 다시 보지 않고 통과시킨다")
    void preAuthenticatedContextShortCircuits() throws Exception {
        UserPrincipal existing = new UserPrincipal(99L, "other@example.com");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(existing, null, null));

        MockFilterChain chain = new MockFilterChain();
        MockHttpServletResponse response = new MockHttpServletResponse();

        // 헤더가 없는데도 통과해야 한다 — 앞선 필터가 세운 인증을 신뢰한다.
        filter.doFilter(get("/api/photos"), response, chain);

        assertThat(response.getStatus()).isEqualTo(HttpServletResponse.SC_OK);
        assertThat(chain.getRequest()).isNotNull();
        assertThat(((UserPrincipal) SecurityContextHolder.getContext()
                .getAuthentication().getPrincipal()).getId()).isEqualTo(99L);
    }

    @Test
    @DisplayName("/api 밖의 경로는 보호 대상이 아니라 토큰 없이 통과한다")
    void nonApiPathIsNotProtected() throws Exception {
        MockFilterChain chain = new MockFilterChain();
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(get("/hello"), response, chain);

        assertThat(response.getStatus()).isEqualTo(HttpServletResponse.SC_OK);
        assertThat(chain.getRequest()).isNotNull();
    }

    private static MockHttpServletRequest get(String uri) {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", uri);
        request.setRequestURI(uri);
        return request;
    }
}
