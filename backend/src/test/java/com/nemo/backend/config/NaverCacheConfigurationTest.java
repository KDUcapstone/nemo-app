package com.nemo.backend.config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.env.PropertySource;
import org.springframework.core.io.ClassPathResource;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;

class NaverCacheConfigurationTest {

    @Test
    void cachePolicyDefaultsAreConfigurable() throws IOException {
        PropertySource<?> properties = new YamlPropertySourceLoader()
                .load("application", new ClassPathResource("application.yml"))
                .getFirst();

        assertThat(properties.getProperty("naver.cache.ttl-ms"))
                .isEqualTo("${NAVER_CACHE_TTL_MS:120000}");
        assertThat(properties.getProperty("naver.cache.maximum-size"))
                .isEqualTo("${NAVER_CACHE_MAXIMUM_SIZE:1000}");
    }
}
