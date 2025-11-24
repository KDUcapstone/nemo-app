// backend/src/main/java/com/nemo/backend/domain/auth/dto/PasswordResetRequest.java
package com.nemo.backend.domain.auth.dto;

/** 비밀번호 분실: 새 비밀번호 설정 요청 */
public record PasswordResetRequest(
        String resetToken,
        String newPassword,
        String confirmPassword
) { }
