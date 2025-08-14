package com.nemo.backend.domain.user.dto;

import java.time.LocalDateTime;

/**
 * Profile response DTO that omits sensitive fields such as password.
 */
public class UserProfileResponse {
    private Long id;
    private String email;
    private String nickname;
    private String profileImageUrl;
    private String provider;
    private String socialId;
    private LocalDateTime createdAt;

    public UserProfileResponse(Long id, String email, String nickname, String profileImageUrl,
                               String provider, String socialId, LocalDateTime createdAt) {
        this.id = id;
        this.email = email;
        this.nickname = nickname;
        this.profileImageUrl = profileImageUrl;
        this.provider = provider;
        this.socialId = socialId;
        this.createdAt = createdAt;
    }

    public Long getId() { return id; }
    public String getEmail() { return email; }
    public String getNickname() { return nickname; }
    public String getProfileImageUrl() { return profileImageUrl; }
    public String getProvider() { return provider; }
    public String getSocialId() { return socialId; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
