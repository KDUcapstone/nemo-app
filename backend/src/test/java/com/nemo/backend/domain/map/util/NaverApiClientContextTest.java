package com.nemo.backend.domain.map.util;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import org.springframework.web.client.RestTemplate;

import static org.assertj.core.api.Assertions.assertThat;

@SpringJUnitConfig(classes = {
        NaverApiClient.class,
        NaverApiClientContextTest.TestConfig.class
})
@TestPropertySource(properties = {
        "NAVER_LOCAL_CLIENT_ID=test-local-id",
        "NAVER_LOCAL_CLIENT_SECRET=test-local-secret",
        "NAVER_MAP_CLIENT_ID=test-map-id",
        "NAVER_MAP_CLIENT_SECRET=test-map-secret",
        "naver.cache.ttl-ms=120000",
        "naver.cache.maximum-size=1000"
})
class NaverApiClientContextTest {

    @Autowired
    private NaverApiClient naverApiClient;

    @Test
    void springCreatesRealNaverApiClient() {
        assertThat(naverApiClient).isNotNull();
    }

    @Configuration
    static class TestConfig {
        @Bean
        RestTemplate restTemplate() {
            return new RestTemplate();
        }
    }
}
