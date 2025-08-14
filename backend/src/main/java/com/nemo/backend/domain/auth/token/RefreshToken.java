package com.nemo.backend.domain.auth.token;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * RefreshToken entity represents a persisted refresh token tied to a user.
 * It is kept in the auth/token sub‑package according to the domain
 * structure.  When a user logs out or their account is deleted, these
 * tokens are removed.
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

    public Long getId() {
        return id;
    }
    public void setId(Long id) {
        this.id = id;
    }
    public Long getUserId() {
        return userId;
    }
    public void setUserId(Long userId) {
        this.userId = userId;
    }
    public String getToken() {
        return token;
    }
    public void setToken(String token) {
        this.token = token;
    }
    public LocalDateTime getExpiry() {
        return expiry;
    }
    public void setExpiry(LocalDateTime expiry) {
        this.expiry = expiry;
    }
}