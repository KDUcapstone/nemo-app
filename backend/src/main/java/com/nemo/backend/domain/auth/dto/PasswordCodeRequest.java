// backend/src/main/java/com/nemo/backend/domain/auth/dto/PasswordCodeRequest.java
package com.nemo.backend.domain.auth.dto;

/** 비밀번호 분실: 인증코드 발송 요청 */
public record PasswordCodeRequest(
        String email
) { }
