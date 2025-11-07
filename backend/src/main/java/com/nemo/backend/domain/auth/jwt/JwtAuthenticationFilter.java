// domain/auth/jwt/JwtAuthenticationFilter.java
package com.nemo.backend.domain.auth.jwt;

import com.nemo.backend.domain.auth.principal.UserPrincipal;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.AntPathMatcher;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * 매 요청마다 Authorization 헤더를 검사해 유효한 경우 SecurityContext에 인증 주체(UserPrincipal)를 설정한다.
 * - 공개 경로(로그인/회원가입/Swagger/H2 등)는 필터를 건너뜀
 * - 보호 경로에서 토큰이 없거나 잘못됐으면 401로 응답
 */
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final AntPathMatcher pathMatcher = new AntPathMatcher();

    // 🔓 이 경로들은 필터를 건너뜁니다 (공개)
    private static final List<String> PUBLIC_PATTERNS = List.of(
            "/h2-console/**",
            "/api/users/signup",
            "/api/users/login",
            "/api/auth/dev/**",
            "/swagger-ui/**",
            "/v3/api-docs/**"
    );

    // 🔒 이 경로들은 토큰이 반드시 필요합니다 (보호)
    //  (SecurityConfig에서도 authenticated()로 맞춰주세요)
    private static final List<String> PROTECTED_PATTERNS = List.of(
            "/api/friends/**"
            // 필요시 여기에 추가
    );

    public JwtAuthenticationFilter(JwtUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {

        String uri = req.getRequestURI();

        // 1) 공개 경로: 그냥 통과
        if (matchesAny(uri, PUBLIC_PATTERNS)) {
            chain.doFilter(req, res);
            return;
        }

        // 2) 이미 인증된 경우(다른 필터가 넣었거나 이전 체인에서 처리): 통과
        if (SecurityContextHolder.getContext().getAuthentication() != null) {
            chain.doFilter(req, res);
            return;
        }

        // 3) 보호 경로: 토큰 필수
        if (matchesAny(uri, PROTECTED_PATTERNS)) {
            String auth = req.getHeader("Authorization");
            if (!StringUtils.hasText(auth)) {
                writeUnauthorized(res, "Authorization header is missing");
                return;
            }

            try {
                Long userId = jwtUtil.getUserId(auth);
                String email = null; // 필요시 jwtUtil.getEmail(auth) 사용
                var principal = new UserPrincipal(userId, email);
                var authentication = new UsernamePasswordAuthenticationToken(principal, null, null);
                SecurityContextHolder.getContext().setAuthentication(authentication);
            } catch (Exception e) {
                log.debug("JWT parse/verify failed: {}", e.getMessage());
                writeUnauthorized(res, e.getMessage());
                return;
            }
        }

        // 4) 그 외 경로: 정책에 따라 허용(permitAll)이라면 통과
        chain.doFilter(req, res);
    }

    private boolean matchesAny(String uri, List<String> patterns) {
        for (String p : patterns) {
            if (pathMatcher.match(p, uri)) return true;
        }
        return false;
    }

    private void writeUnauthorized(HttpServletResponse res, String message) throws IOException {
        res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        res.setContentType("application/json;charset=UTF-8");
        res.getWriter().write("{\"error\":\"UNAUTHORIZED\",\"message\":\"" + message + "\"}");
    }
}
