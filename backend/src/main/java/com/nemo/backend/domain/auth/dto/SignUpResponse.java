// backend/src/main/java/com/nemo/backend/domain/auth/dto/SignUpResponse.java
package com.nemo.backend.domain.auth.dto;

public class SignUpResponse {
    private Long userId;
    private String email;
    private String nickname;
    private String profileImageUrl;

    public SignUpResponse() { } // ✅ Jackson 기본 생성자

    public SignUpResponse(Long userId, String email, String nickname, String profileImageUrl) {
        this.userId = userId;
        this.email = email;
        this.nickname = nickname == null ? "" : nickname;
        this.profileImageUrl = profileImageUrl == null ? "" : profileImageUrl;
    }

    public Long getUserId() { return userId; }
    public String getEmail() { return email; }
    public String getNickname() { return nickname; }
    public String getProfileImageUrl() { return profileImageUrl; }
}
