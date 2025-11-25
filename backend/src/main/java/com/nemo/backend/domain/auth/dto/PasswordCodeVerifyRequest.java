// backend/src/main/java/com/nemo/backend/domain/auth/dto/PasswordCodeVerifyRequest.java
package com.nemo.backend.domain.auth.dto;

/** 비밀번호 분실: 인증코드 검증(토큰 발급) 요청 */
public record PasswordCodeVerifyRequest(
        String email,
        String code
) { }
