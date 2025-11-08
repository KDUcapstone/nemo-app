package com.nemo.backend.domain.auth.dto;

import lombok.Getter;

/**
 * Response returned after a successful sign‑up.  Contains only public
 * user details.
 */
@Getter
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

}