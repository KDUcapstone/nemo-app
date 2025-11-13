package com.nemo.backend.domain.auth.dto;

import lombok.Getter;

/**
 * DTO representing the body of a sign‑up request.  All fields are required
 * except for password when registering via a social provider.
 */
@Getter
public class SignUpRequest {
    private String email;
    private String password;
    private String nickname;

    public void setEmail(String email) {
        this.email = email;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public void setNickname(String nickname) {
        this.nickname = nickname;
    }
}