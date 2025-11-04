package com.nemo.backend.global.health;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class DbHealthController {

    private final JdbcTemplate jdbc;

    public DbHealthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/health/db")
    public String checkDbConnection() {
        try {
            Integer result = jdbc.queryForObject("SELECT 1", Integer.class);
            if (result != null && result == 1) {
                return "✅ DB 연결 성공! CloudType MariaDB와 통신 중입니다.";
            } else {
                return "⚠️ DB 연결 시도는 됐지만, 응답이 올바르지 않습니다.";
            }
        } catch (Exception e) {
            return "❌ DB 연결 실패: " + e.getMessage();
        }
    }
}
