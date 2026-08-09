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
 *   "isNewUser": false,
 *   "user": {
 *     "userId": 1,
 *     "nickname": "닉네임",
 *     "profileImageUrl": "https://.../profile.jpg",
 *     "provider": "local" | "kakao" | "google"
 *   }
 * }
 */
@Getter
public class LoginResponse {

    private final String accessToken;
    private final String refreshToken;
    private final long expiresIn;
    private final boolean isNewUser;
    private final UserSummary user;

    public LoginResponse(String accessToken,
                         String refreshToken,
                         long expiresIn,
                         boolean isNewUser,
                         Long userId,
                         String nickname,
                         String profileImageUrl,
                         String provider) {               // 👈 provider 추가
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
        this.expiresIn = expiresIn;
        this.isNewUser = isNewUser;
        this.user = new UserSummary(userId, nickname, profileImageUrl, provider);
    }

    @Getter
    public static class UserSummary {
        private final Long userId;
        private final String nickname;
        private final String profileImageUrl;
        private final String provider;   // 👈 추가

        public UserSummary(Long userId,
                           String nickname,
                           String profileImageUrl,
                           String provider) {
            this.userId = (userId == null ? 0L : userId);
            this.nickname = (nickname == null ? "" : nickname);
            this.profileImageUrl = (profileImageUrl == null ? "" : profileImageUrl);
            this.provider = (provider == null ? "local" : provider);
        }
    }
}
