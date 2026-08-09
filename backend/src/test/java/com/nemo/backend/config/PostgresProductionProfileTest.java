package com.nemo.backend.config;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.env.PropertySource;
import org.springframework.core.io.ClassPathResource;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

class PostgresProductionProfileTest {

    private PropertySource<?> baseProperties;
    private PropertySource<?> localProperties;
    private PropertySource<?> productionProperties;

    @BeforeEach
    void loadProductionProfile() throws IOException {
        YamlPropertySourceLoader loader = new YamlPropertySourceLoader();
        baseProperties = loader
                .load("application", new ClassPathResource("application.yml"))
                .getFirst();
        localProperties = loader
                .load("application-local", new ClassPathResource("application-local.yml"))
                .getFirst();
        productionProperties = loader
                .load("application-prod", new ClassPathResource("application-prod.yml"))
                .getFirst();
    }

    @Test
    void defaultExecutionUsesDevUnlessProfileIsExplicitlyProvided() {
        assertThat(baseProperty("spring.profiles.active"))
                .isEqualTo("${SPRING_PROFILES_ACTIVE:dev}");
    }

    @Test
    void productionProfileUsesPostgresWithEnvironmentBackedCredentials() {
        assertThat(property("spring.datasource.driver-class-name"))
                .isEqualTo("org.postgresql.Driver");
        assertThat(property("spring.datasource.url"))
                .isEqualTo("${DB_URL}");
        assertThat(property("spring.datasource.username"))
                .isEqualTo("${DB_USER}");
        assertThat(property("spring.datasource.password"))
                .isEqualTo("${DB_PASSWORD}");
        assertThat(property("spring.jpa.database-platform"))
                .isEqualTo("org.hibernate.dialect.PostgreSQLDialect");
        assertThat(property("spring.jpa.hibernate.ddl-auto"))
                .isEqualTo("validate");
    }

    @Test
    void productionSecretsAndPublicUrlComeFromEnvironment() {
        assertThat(property("app.jwt.secret"))
                .isEqualTo("${JWT_SECRET}");
        assertThat(property("app.public-base-url"))
                .isEqualTo("${PUBLIC_BASE_URL}");
    }

    @Test
    void localProfileDoesNotStoreDatabaseJwtOrPublicUrlValues() {
        assertThat(localProperty("spring.datasource.url"))
                .isEqualTo("${DB_URL}");
        assertThat(localProperty("spring.datasource.username"))
                .isEqualTo("${DB_USER}");
        assertThat(localProperty("spring.datasource.password"))
                .isEqualTo("${DB_PASSWORD}");
        assertThat(localProperty("app.jwt.secret"))
                .isEqualTo("${JWT_SECRET}");
        assertThat(localProperty("app.public-base-url"))
                .isEqualTo("${PUBLIC_BASE_URL:http://localhost:8080}");
    }

    @Test
    void productionProfileDisablesDevelopmentSurfacesAndLimitsActuator() {
        assertThat(property("spring.h2.console.enabled")).isEqualTo(false);
        assertThat(property("springdoc.api-docs.enabled")).isEqualTo(false);
        assertThat(property("springdoc.swagger-ui.enabled")).isEqualTo(false);
        assertThat(property("management.endpoints.web.exposure.include"))
                .isEqualTo("health,info");
        assertThat(property("management.endpoint.health.show-details"))
                .isEqualTo("never");
    }

    @Test
    void postgresDriverIsAvailableAtRuntime() {
        assertThatCode(() -> Class.forName("org.postgresql.Driver"))
                .doesNotThrowAnyException();
    }

    private Object property(String key) {
        return productionProperties.getProperty(key);
    }

    private Object baseProperty(String key) {
        return baseProperties.getProperty(key);
    }

    private Object localProperty(String key) {
        return localProperties.getProperty(key);
    }
}
