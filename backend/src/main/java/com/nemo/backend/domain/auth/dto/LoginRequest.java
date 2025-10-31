// backend/src/main/java/com/nemo/backend/domain/auth/dto/LoginRequest.java
package com.nemo.backend.domain.auth.dto;

/**
 * 로그인 요청 DTO.  이메일과 비밀번호를 받는다.
 */
public class LoginRequest {
    private String email;
    private String password;

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
}
