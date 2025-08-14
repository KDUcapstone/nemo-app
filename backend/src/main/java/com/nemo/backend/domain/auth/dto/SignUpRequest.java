package com.nemo.backend.domain.auth.dto;

/**
 * DTO representing the body of a sign‑up request.  All fields are required
 * except for password when registering via a social provider.
 */
public class SignUpRequest {
    private String email;
    private String password;
    private String nickname;

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getNickname() {
        return nickname;
    }

    public void setNickname(String nickname) {
        this.nickname = nickname;
    }
}