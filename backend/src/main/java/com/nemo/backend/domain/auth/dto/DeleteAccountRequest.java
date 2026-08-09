// backend/src/main/java/com/nemo/backend/domain/auth/dto/DeleteAccountRequest.java
package com.nemo.backend.domain.auth.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 회원 탈퇴 시 프론트가 보내는 비밀번호를 담는 DTO.
 */
public class DeleteAccountRequest {
    // 예전
    // @NotBlank(message = "공백일 수 없습니다")
    // private String password;

    // 변경 후
    private String password;

    public DeleteAccountRequest() {}
    public DeleteAccountRequest(String password) { this.password = password; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
}
