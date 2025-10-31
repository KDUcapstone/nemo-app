// backend/src/main/java/com/nemo/backend/domain/user/dto/UserProfileResponse.java
package com.nemo.backend.domain.user.dto;

public class UserProfileResponse {
    private Long userId;
    private String email;
    private String nickname;        // 절대 null 안 내려가게
    private String profileImageUrl; // 절대 null 안 내려가게

    public UserProfileResponse(Long userId, String email, String nickname, String profileImageUrl) {
        this.userId = userId;
        this.email = email;
        this.nickname = nickname != null ? nickname : "";
        this.profileImageUrl = profileImageUrl != null ? profileImageUrl : "";
    }

    public Long getUserId() { return userId; }
    public String getEmail() { return email; }
    public String getNickname() { return nickname; }
    public String getProfileImageUrl() { return profileImageUrl; }
}
