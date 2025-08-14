package com.nemo.backend.domain.user.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * User entity representing an account within the system.  It lives in the
 * user domain because it models profile and identity information rather than
 * authentication concerns.
 */
@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, unique = true)
    private String email;
    @Column
    private String password;
    @Column(nullable = false)
    private String nickname;
    @Column
    private String profileImageUrl;
    @Column(nullable = false)
    private String provider = "LOCAL";
    @Column(unique = true)
    private String socialId;
    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public Long getId() {
        return id;
    }
    public void setId(Long id) {
        this.id = id;
    }
    public String getEmail() {
        return email;
    }
    public void setEmail(String email) {
        this.email = email;
    }
    public String getPassword() {
        return password;
    }
    public void setPassword(String password) {
        this.password = password;
    }
    public String getNickname() {
        return nickname;
    }
    public void setNickname(String nickname) {
        this.nickname = nickname;
    }
    public String getProfileImageUrl() {
        return profileImageUrl;
    }
    public void setProfileImageUrl(String profileImageUrl) {
        this.profileImageUrl = profileImageUrl;
    }
    public String getProvider() {
        return provider;
    }
    public void setProvider(String provider) {
        this.provider = provider;
    }
    public String getSocialId() {
        return socialId;
    }
    public void setSocialId(String socialId) {
        this.socialId = socialId;
    }
    public LocalDateTime getCreatedAt() {
        return createdAt;
    }
    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}