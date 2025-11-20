package com.nemo.backend.domain.user.dto;

import java.time.LocalDateTime;

/**
 * 현재 로그인한 사용자의 프로필 정보를 나타내는 DTO.
 * null 값이 전달될 경우 빈 문자열로 대체하여 Flutter에서
 *  `Null is not a subtype of String` 오류를 방지합니다.
 *
 * 응답 JSON 필드:
 *  - userId
 *  - email
 *  - nickname
 *  - profileImageUrl
 *  - createdAt
 */
public class UserProfileResponse {
    private Long userId;             // ✅ 명세: userId
    private String email;
    private String nickname;
    private String profileImageUrl;  // ✅ 명세: profileImageUrl
    private String createdAt;        // ISO-8601 문자열

    public UserProfileResponse() {}

    public UserProfileResponse(Long userId,
                               String email,
                               String nickname,
                               String profileImageUrl,
                               LocalDateTime createdAt) {
        this.userId = (userId == null ? 0L : userId);
        this.email = (email == null ? "" : email);
        this.nickname = (nickname == null ? "" : nickname);
        this.profileImageUrl = (profileImageUrl == null ? "" : profileImageUrl);
        this.createdAt = (createdAt == null ? "" : createdAt.toString());
    }

    public Long getUserId() { return userId; }
    public String getEmail() { return email; }
    public String getNickname() { return nickname; }
    public String getProfileImageUrl() { return profileImageUrl; }
    public String getCreatedAt() { return createdAt; }
}
