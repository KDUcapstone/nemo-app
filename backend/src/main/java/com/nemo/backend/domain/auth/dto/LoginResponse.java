// backend/src/main/java/com/nemo/backend/domain/auth/dto/LoginResponse.java
package com.nemo.backend.domain.auth.dto;

/**
 * 로그인 성공 시 반환 DTO. 사용자 기본 정보와 액세스/리프레시 토큰을 포함한다.
 */
public class LoginResponse {
    private Long userId;
    private String email;
    private String nickname;        // null 금지
    private String profileImageUrl; // null 금지
    private String accessToken;
    private String refreshToken;

    public LoginResponse(Long userId, String email, String nickname,
                         String profileImageUrl, String accessToken, String refreshToken) {
        this.userId = userId;
        this.email = email;
        this.nickname = nickname != null ? nickname : "";
        this.profileImageUrl = profileImageUrl != null ? profileImageUrl : "";
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
    }

    // getters...
}
