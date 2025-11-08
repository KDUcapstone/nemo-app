// src/main/java/com/nemo/backend/config/LogConfig.java
package com.nemo.backend.config;

import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.*;

@Slf4j
@Configuration
public class LogConfig implements WebMvcConfigurer {
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new HandlerInterceptor() {
            @Override
            public boolean preHandle(HttpServletRequest req, jakarta.servlet.http.HttpServletResponse res, Object handler) {
                log.info("[REQ] {} {} UA={}", req.getMethod(), req.getRequestURI(), req.getHeader("User-Agent"));
                log.info("Authorization={}", req.getHeader("Authorization"));
                return true;
            }
        }).addPathPatterns("/api/**");
    }
}
