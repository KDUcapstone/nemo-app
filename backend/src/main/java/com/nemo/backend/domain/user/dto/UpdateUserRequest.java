package com.nemo.backend.domain.user.dto;

/**
 * Payload for updating user profile information.
 * 모든 필드는 optional 이고,
 * 넘겨진 값만 업데이트한다.
 */
public class UpdateUserRequest {
    private String nickname;
    private String profileImageUrl;

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

    public boolean hasAnyField() {
        return (nickname != null && !nickname.isEmpty())
                || (profileImageUrl != null && !profileImageUrl.isEmpty());
    }
}
