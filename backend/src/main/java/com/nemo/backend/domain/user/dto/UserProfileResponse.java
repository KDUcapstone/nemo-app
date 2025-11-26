// backend/src/main/java/com/nemo/backend/domain/user/dto/UserProfileResponse.java
package com.nemo.backend.domain.user.dto;

import java.time.LocalDateTime;

/**
 * 현재 로그인한 사용자의 프로필 정보 DTO.
 *
 * 응답 JSON 필드:
 *  - userId
 *  - email
 *  - nickname
 *  - profileImageUrl
 *  - createdAt
 *
 * null 값이 들어와도 Flutter에서 NPE 안 나게
 * 적당한 기본값으로 보정한다.
 */
public class UserProfileResponse {

    private Long userId;
    private String email;
    private String nickname;
    private String profileImageUrl;
    private String createdAt;

    // Jackson 기본 생성자
    public UserProfileResponse() {
    }

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

    public Long getUserId() {
        return userId;
    }

    public String getEmail() {
        return email;
    }

    public String getNickname() {
        return nickname;
    }

    public String getProfileImageUrl() {
        return profileImageUrl;
    }

    public String getCreatedAt() {
        return createdAt;
    }
}
