package com.nemo.backend.global.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

/**
 * 개발 단계: 컨트롤러 단에서 JWT/리프레시 토큰을 직접 검사.
 * H2 콘솔/회원가입/로그인/파일 프록시(/files/**) 등은 공개.
 * 그 외 엔드포인트도 일단 permitAll() 후 컨트롤러에서 401 처리.
 */
@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(
                                // 공개 엔드포인트
                                "/h2-console/**",
                                "/api/users/signup",
                                "/api/users/login",
                                "/files/**",            // ← S3 프록시 이미지/영상 공개
                                "/swagger-ui/**",
                                "/v3/api-docs/**",
                                "/actuator/health"
                        ).permitAll()
                        // 개발 단계: 나머지도 일단 열어두고 컨트롤러에서 자체 인증 처리
                        .anyRequest().permitAll()
                )
                // H2 콘솔/단순 폼 테스트 등을 위해 CSRF 비활성화
                .csrf(csrf -> csrf.disable())
                // H2 콘솔 iframe 허용
                .headers(headers -> headers.frameOptions(frame -> frame.disable()));

        return http.build();
    }
}
