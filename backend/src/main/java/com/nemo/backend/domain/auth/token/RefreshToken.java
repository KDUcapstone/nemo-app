// backend/src/main/java/com/nemo/backend/domain/auth/token/RefreshToken.java
package com.nemo.backend.domain.auth.token;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * RefreshToken 엔티티.  userId, token, expiry 를 저장한다.
 */
@Entity
@Table(name = "refresh_tokens")
public class RefreshToken {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false)
    private Long userId;
    @Column(nullable = false, unique = true)
    private String token;
    @Column
    private LocalDateTime expiry;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }
    public LocalDateTime getExpiry() { return expiry; }
    public void setExpiry(LocalDateTime expiry) { this.expiry = expiry; }
}
