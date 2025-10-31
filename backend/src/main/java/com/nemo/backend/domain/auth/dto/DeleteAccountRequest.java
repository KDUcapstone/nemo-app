// backend/src/main/java/com/nemo/backend/domain/auth/dto/DeleteAccountRequest.java
package com.nemo.backend.domain.auth.dto;

import jakarta.validation.constraints.NotBlank;

public class DeleteAccountRequest {
    @NotBlank
    private String password;

    public DeleteAccountRequest() {}
    public DeleteAccountRequest(String password) { this.password = password; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
}
