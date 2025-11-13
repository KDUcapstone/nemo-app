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
 * - 공개 경로: H2 콘솔, 회원가입/로그인, Swagger 문서
 * - 인증 필요: /api/friends/** (그리고 추후 보호가 필요한 API들)
 * - 매 요청마다 JWT 필터로 토큰을 검사하고, 성공 시 SecurityContext에 UserPrincipal 저장
 */
@Configuration
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtUtil jwtUtil; // 🔸 JwtAuthenticationFilter에 주입할 유틸

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                // 세션을 쓰지 않는 완전한 Stateless API 서버 모드
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

                // 권한 규칙
                .authorizeHttpRequests(auth -> auth
                        // 🔓 공개 허용
                        .requestMatchers(
                                "/h2-console/**",
                                "/api/users/signup",
                                "/api/users/login",
                                "/api/auth/refresh",
                                "/api/auth/dev/**",
                                "/api/users/login",
                                "/swagger-ui/**",
                                "/v3/api-docs/**",
                                "/api/auth/dev/**",
                                "/files/**",
                                "/actuator/**"
                        ).permitAll()

                        // 🔒 친구 API는 인증 필요(토큰 필수) — 필요 시 여기에 보호 경로 추가
                        .requestMatchers("/api/friends/**").authenticated()

                        // 나머지는 상황에 맞게: 우선은 허용(필요해지면 authenticated로 변경)
                        .anyRequest().permitAll()
                )

                // CSRF/CORS/H2 콘솔 프레임
                .csrf(csrf -> csrf.disable())
                .headers(h -> h.frameOptions(f -> f.disable()));

        // 🔗 JWT 필터 등록: UsernamePasswordAuthenticationFilter 앞에서 토큰 검증
        http.addFilterBefore(new JwtAuthenticationFilter(jwtUtil), UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
