package com.nemo.backend.global.security;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * ✅ application.yml에 적어둔 JWT 설정값을 주입받는 클래스
 */
@Setter
@Getter
@Component
@ConfigurationProperties(prefix = "app.jwt")
public class JwtProperties {
    private String secret;      // 서명용 시크릿
    private String issuer;      // 발급자
    private long accessTtlMs;   // 액세스 토큰 만료(ms)

}
