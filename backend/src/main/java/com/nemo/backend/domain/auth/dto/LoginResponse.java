// backend/src/main/java/com/nemo/backend/domain/auth/dto/LoginResponse.java
package com.nemo.backend.domain.auth.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class LoginResponse {
    // 프론트가 userId 또는 id 중 무엇을 읽어도 되도록 둘 다 매핑
    @JsonProperty("userId")
    private Long userId;

    @JsonProperty("id") // 호환 필드(프론트가 id만 읽는 경우 대비)
    private Long id;

    private String email;
    private String nickname;
    private String profileImageUrl;
    private String accessToken;
    private String refreshToken;

    public LoginResponse() {}

    public LoginResponse(Long userId, String email, String nickname,
                         String profileImageUrl, String accessToken, String refreshToken) {
        Long safeId = (userId == null ? 0L : userId);
        this.userId = safeId;
        this.id = safeId; // 두 키 모두 같은 값
        this.email = email == null ? "" : email;
        this.nickname = nickname == null ? "" : nickname;
        this.profileImageUrl = profileImageUrl == null ? "" : profileImageUrl;
        this.accessToken = accessToken == null ? "" : accessToken;
        this.refreshToken = refreshToken == null ? "" : refreshToken;
    }

    public Long getUserId() { return userId; }
    public Long getId() { return id; }
    public String getEmail() { return email; }
    public String getNickname() { return nickname; }
    public String getProfileImageUrl() { return profileImageUrl; }
    public String getAccessToken() { return accessToken; }
    public String getRefreshToken() { return refreshToken; }
}
