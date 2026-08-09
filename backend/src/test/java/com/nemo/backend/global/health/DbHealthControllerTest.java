package com.nemo.backend.global.health;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DbHealthControllerTest {

    @Mock
    private JdbcTemplate jdbcTemplate;

    @Test
    void reportsPostgresUpWhenSelectOneSucceeds() {
        when(jdbcTemplate.queryForObject("SELECT 1", Integer.class)).thenReturn(1);
        DbHealthController controller = new DbHealthController(jdbcTemplate);

        Object result = controller.checkDbConnection();

        assertThat(result).isInstanceOf(ResponseEntity.class);
        ResponseEntity<?> response = (ResponseEntity<?>) result;
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(Map.of(
                "status", "UP",
                "database", "PostgreSQL"
        ));
    }

    @Test
    void reportsServiceUnavailableWithoutLeakingDatabaseError() {
        when(jdbcTemplate.queryForObject("SELECT 1", Integer.class))
                .thenThrow(new IllegalStateException("secret host unavailable"));
        DbHealthController controller = new DbHealthController(jdbcTemplate);

        Object result = controller.checkDbConnection();

        assertThat(result).isInstanceOf(ResponseEntity.class);
        ResponseEntity<?> response = (ResponseEntity<?>) result;
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
        assertThat(response.getBody()).isEqualTo(Map.of(
                "status", "DOWN",
                "database", "PostgreSQL"
        ));
        assertThat(response.toString()).doesNotContain("secret host unavailable");
    }
}
