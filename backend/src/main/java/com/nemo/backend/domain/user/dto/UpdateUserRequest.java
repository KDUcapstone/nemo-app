package com.nemo.backend.domain.user.dto;

/**
 * Payload for updating user profile information.  All fields are optional; any
 * provided fields will overwrite the corresponding values on the user
 * entity.
 */
public class UpdateUserRequest {
    private String nickname;
    private String profileImageUrl;
    private String password;

    public String getNickname() {
        return nickname;
    }

    public void setNickname(String nickname) {
        this.nickname = nickname;
    }

    public String getProfileImageUrl() {
        return profileImageUrl;
    }

    public void setProfileImageUrl(String profileImageUrl) {
        this.profileImageUrl = profileImageUrl;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}