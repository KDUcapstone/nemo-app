// backend/src/main/java/com/nemo/backend/domain/user/dto/UserProfileResponse.java
package com.nemo.backend.domain.user.dto;

public class UserProfileResponse {
    private Long userId;
    private String email;
    private String nickname;
    private String profileImageUrl;

    public UserProfileResponse() {}

    public UserProfileResponse(Long userId, String email, String nickname, String profileImageUrl) {
        this.userId = (userId == null ? 0L : userId);
        this.email = (email == null ? "" : email);
        this.nickname = (nickname == null ? "" : nickname);
        this.profileImageUrl = (profileImageUrl == null ? "" : profileImageUrl);
    }

    public Long getUserId() { return userId; }
    public String getEmail() { return email; }
    public String getNickname() { return nickname; }
    public String getProfileImageUrl() { return profileImageUrl; }
}
