package com.nemo.backend.domain.auth.dto;

/**
 * Response returned upon successful login.  Contains basic user details and
 * both access and refresh tokens.
 */
public class LoginResponse {
    private Long id;
    private String email;
    private String nickname;
    private String profileImageUrl;
    private String accessToken;
    private String refreshToken;

    public LoginResponse(Long id, String email, String nickname, String profileImageUrl,
                         String accessToken, String refreshToken) {
        this.id = id;
        this.email = email;
        this.nickname = nickname;
        this.profileImageUrl = profileImageUrl;
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
    }

    public Long getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getNickname() {
        return nickname;
    }

    public String getProfileImageUrl() {
        return profileImageUrl;
    }

    public String getAccessToken() {
        return accessToken;
    }

    public String getRefreshToken() {
        return refreshToken;
    }
}