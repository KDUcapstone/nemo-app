package com.nemo.backend.domain.auth.dto;

import lombok.Getter;

/**
 * Response returned upon successful login.  Contains basic user details and
 * both access and refresh tokens.
 */
@Getter
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

}