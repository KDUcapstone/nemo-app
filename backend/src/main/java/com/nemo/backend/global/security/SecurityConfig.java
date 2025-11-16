// backend/src/main/java/com/nemo/backend/global/security/SecurityConfig.java
package com.nemo.backend.global.security;

import com.nemo.backend.domain.auth.jwt.JwtAuthenticationFilter;
import com.nemo.backend.domain.auth.jwt.JwtUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * ✅ 스프링 시큐리티 설정
 * - 공개 경로: H2 콘솔, Swagger, 파일, 헬스체크, 회원가입/로그인, 이메일 인증, 비밀번호 재설정, 토큰 재발급, dev 시드
 * - 인증 필요: 그 외 /api/** 전체 (ex. /api/users/me, /api/photos, /api/albums, /api/friends ...)
 * - 매 요청마다 JWT 필터로 토큰을 검증하고, 성공 시 SecurityContext에 UserPrincipal 저장
 */
@Configuration
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtUtil jwtUtil;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {

        http
                // 세션을 쓰지 않는 완전한 Stateless API 서버 모드
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

                // 권한 규칙
                .authorizeHttpRequests(auth -> auth
                        // 🔓 토큰 없이 접근 가능한 공개 엔드포인트
                        .requestMatchers(
                                "/h2-console/**",
                                "/swagger-ui/**",
                                "/v3/api-docs/**",
                                "/files/**",
                                "/actuator/**",

                                "/api/users/signup",
                                "/api/users/login",

                                // 이메일 인증
                                "/api/auth/email/**",

                                // 비밀번호 찾기 / 재설정
                                "/api/auth/password/**",
                                "/api/users/password/**",

                                // 토큰 재발급 및 dev 시드
                                "/api/auth/refresh",
                                "/api/auth/dev/**"
                        ).permitAll()

                        // 🔒 그 외 모든 /api/** 는 인증 필요
                        .requestMatchers("/api/**").authenticated()

                        // 그 밖의 정적 리소스 등은 일단 허용
                        .anyRequest().permitAll()
                )

                // CSRF 비활성화 + H2 콘솔을 위한 frameOptions 해제
                .csrf(csrf -> csrf.disable())
                .headers(headers -> headers.frameOptions(frame -> frame.disable()));

        // 🔗 JWT 필터 등록: UsernamePasswordAuthenticationFilter 앞에서 토큰 검증
        http.addFilterBefore(new JwtAuthenticationFilter(jwtUtil), UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
