package com.nemo.backend.global.health;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class DbHealthController {

    private final JdbcTemplate jdbc;

    public DbHealthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/health/db")
    public ResponseEntity<Map<String, String>> checkDbConnection() {
        try {
            Integer result = jdbc.queryForObject("SELECT 1", Integer.class);
            if (result != null && result == 1) {
                return ResponseEntity.ok(Map.of(
                        "status", "UP",
                        "database", "PostgreSQL"
                ));
            }
        } catch (Exception ignored) {
            // Health responses must not leak connection details.
        }

        return ResponseEntity.status(503).body(Map.of(
                "status", "DOWN",
                "database", "PostgreSQL"
        ));
    }
}
