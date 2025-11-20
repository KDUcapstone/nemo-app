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
    public GroupedOpenApi mapApi() {
        return GroupedOpenApi.builder()
                .group("map")
                .pathsToMatch("/api/map/**")
                .build();
    }


    @Bean
    public GroupedOpenApi friendApi() {
        return GroupedOpenApi.builder()
                .group("friend")
                .pathsToMatch("/api/friends/**")
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
    @Bean
    public GroupedOpenApi photoApi() {
        return GroupedOpenApi.builder()
                .group("photo")
                .pathsToMatch("/api/photos/**")
                .build();
    }
}
