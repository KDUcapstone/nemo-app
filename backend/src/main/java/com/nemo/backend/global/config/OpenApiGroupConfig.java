package com.nemo.backend.global.config;

import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiGroupConfig {

    @Bean
    public GroupedOpenApi authApi() {
        return GroupedOpenApi.builder()
                .group("auth")
                .pathsToMatch("/api/auth/**")
                .build();
    }

    @Bean
    public GroupedOpenApi userApi() {
        return GroupedOpenApi.builder()
                .group("user")
                .pathsToMatch("/api/users/**")
                .build();
    }

    @Bean
    public GroupedOpenApi albumApi() {
        return GroupedOpenApi.builder()
                .group("album")
                .pathsToMatch("/api/albums/**")
                .build();
    }

    @Bean
    public GroupedOpenApi etcApi() {
        return GroupedOpenApi.builder()
                .group("etc")
                .pathsToMatch("/api/**")
                .pathsToExclude("/api/auth/**", "/api/users/**", "/api/albums/**")
                .build();
    }
}
