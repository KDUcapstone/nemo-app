// backend/src/main/java/com/nemo/backend/domain/auth/dto/SignUpResponse.java
package com.nemo.backend.domain.auth.dto;

import lombok.Getter;

/**
 * 회원가입 성공 응답 DTO.
 *
 * 응답 JSON 예:
 * {
 *   "userId": 1,
 *   "email": "user@example.com",
 *   "nickname": "닉네임",
 *   "profileImageUrl": "https://.../profile.jpg",
 *   "createdAt": "2025-11-23T00:12:34"
 * }
 */
@Getter
public class SignUpResponse {

    private final Long userId;
    private final String email;
    private final String nickname;
    private final String profileImageUrl;
    private final String createdAt;

    public SignUpResponse(Long userId,
                          String email,
                          String nickname,
                          String profileImageUrl,
                          String createdAt) {
        this.userId = (userId == null ? 0L : userId);
        this.email = (email == null ? "" : email);
        this.nickname = (nickname == null ? "" : nickname);
        this.profileImageUrl = (profileImageUrl == null ? "" : profileImageUrl);
        this.createdAt = (createdAt == null ? "" : createdAt);
    }
}
