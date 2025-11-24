// backend/src/main/java/com/nemo/backend/domain/auth/dto/EmailVerificationRequest.java
package com.nemo.backend.domain.auth.dto;

/**
 * 이메일 인증 API 공용 요청 DTO
 *
 * - 코드 발송: email 만 전송
 * - 코드 검증: email + code 전송
 */
public record EmailVerificationRequest(
        String email,
        String code
) { }
