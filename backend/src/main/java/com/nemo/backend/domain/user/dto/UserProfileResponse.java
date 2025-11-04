package com.nemo.backend.domain.user.dto;

import java.time.LocalDateTime;

/**
 * 현재 사용자 프로필 응답 DTO.
 */
public class UserProfileResponse {
    private final Long id;
    private final String email;
    private final String nickname;
    private final String profileImageUrl;
    private final String provider;
    private final String socialId;
    private final LocalDateTime createdAt;

    public UserProfileResponse(Long id,
                               String email,
                               String nickname,
                               String profileImageUrl,
                               String provider,
                               String socialId,
                               LocalDateTime createdAt) {
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


