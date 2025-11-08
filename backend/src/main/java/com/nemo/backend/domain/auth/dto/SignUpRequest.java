// backend/src/main/java/com/nemo/backend/domain/auth/dto/SignUpRequest.java
package com.nemo.backend.domain.auth.dto;

/**
 * 회원 가입 요청 DTO.  이메일, 비밀번호, 닉네임을 받는다.
 */
public class SignUpRequest {
    private String email;
    private String password;
    private String nickname;

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    public String getNickname() { return nickname; }
    public void setNickname(String nickname) { this.nickname = nickname; }
}
