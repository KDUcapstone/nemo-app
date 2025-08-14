package com.nemo.backend.domain.auth.dto;

/**
 * Response returned after a successful sign‑up.  Contains only public
 * user details.
 */
public class SignUpResponse {
    private Long id;
    private String email;
    private String nickname;
    private String profileImageUrl;

    public SignUpResponse(Long id, String email, String nickname, String profileImageUrl) {
        this.id = id;
        this.email = email;
        this.nickname = nickname;
        this.profileImageUrl = profileImageUrl;
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
}