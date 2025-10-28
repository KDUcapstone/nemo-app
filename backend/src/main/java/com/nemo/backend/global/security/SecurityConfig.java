package com.nemo.backend.global.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

/**
 * 개발 단계에선 컨트롤러 단에서 JWT/리프레시 토큰 존재 여부를 엄격히 검사한다.
 * H2 콘솔/회원가입/로그인은 공개로 두고, 나머지는 컨트롤러에서 자체 401 처리.
 */
@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(
                                "/h2-console/**",
                                "/api/users/signup",
                                "/api/users/login"
                        ).permitAll()
                        // 나머지는 컨트롤러 단에서 인증/인가 검증 (JWT + refresh 존재)
                        .anyRequest().permitAll()
                )
                .csrf(csrf -> csrf.disable())
                .headers(headers -> headers.frameOptions(frame -> frame.disable())); // H2 iframe 허용

        return http.build();
    }
}
