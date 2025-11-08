package com.nemo.backend.domain.auth.dto;

import lombok.Getter;

/**
 * 로그인할 때 사용되는 요청 본문입니다.  이메일과 비밀번호가 모두 필요합니다.
 */
@Getter
public class LoginRequest {
    private String email;
    private String password;

    public void setEmail(String email) {
        this.email = email;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}