// backend/src/main/java/com/nemo/backend/domain/auth/dto/LoginResponse.java
package com.nemo.backend.domain.auth.dto;

import lombok.Getter;

/**
 * 로그인 성공 응답 DTO.
 *
 * 응답 JSON 예:
 * {
 *   "accessToken": "xxx.yyy.zzz",
 *   "refreshToken": "uuid-....",
 *   "expiresIn": 3600,
 *   "user": {
 *     "userId": 1,
 *     "nickname": "닉네임",
 *     "profileImageUrl": "https://.../profile.jpg"
 *   }
 * }
 */
@Getter
public class LoginResponse {

    private final String accessToken;
    private final String refreshToken;
    private final long expiresIn;
    private final UserSummary user;

    public LoginResponse(String accessToken,
                         String refreshToken,
                         long expiresIn,
                         Long userId,
                         String nickname,
                         String profileImageUrl) {
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
        this.expiresIn = expiresIn;
        this.user = new UserSummary(userId, nickname, profileImageUrl);
    }

    @Getter
    public static class UserSummary {
        private final Long userId;
        private final String nickname;
        private final String profileImageUrl;

        public UserSummary(Long userId, String nickname, String profileImageUrl) {
            this.userId = (userId == null ? 0L : userId);
            this.nickname = (nickname == null ? "" : nickname);
            this.profileImageUrl = (profileImageUrl == null ? "" : profileImageUrl);
        }
    }
}
