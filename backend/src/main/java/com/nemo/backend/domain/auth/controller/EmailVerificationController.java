// backend/src/main/java/com/nemo/backend/domain/auth/controller/EmailVerificationController.java
package com.nemo.backend.domain.auth.controller;

import com.nemo.backend.domain.auth.dto.EmailVerificationRequest;
import com.nemo.backend.domain.auth.service.EmailVerificationService;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping(
        value = "/api/auth/email/verify",
        produces = "application/json; charset=UTF-8"
)
@RequiredArgsConstructor
public class EmailVerificationController {

    private final EmailVerificationService emailVerificationService;

    /**
     * ✅ 이메일 인증 (코드 발송 / 검증)
     *
     * POST /api/auth/email/verify
     *
     * 1) 코드 발송
     *    { "email": "user@example.com" }
     *
     * 2) 코드 검증
     *    { "email": "user@example.com", "code": "812394" }
     */
    @PostMapping
    public ResponseEntity<?> verify(@RequestBody EmailVerificationRequest request) {
        try {
            if (request.code() == null || request.code().isBlank()) {
                // 1) 코드 발송
                emailVerificationService.sendVerificationCode(request.email());
                return ResponseEntity.ok(
                        Map.of("message", "인증코드가 이메일로 발송되었습니다.")
                );
            } else {
                // 2) 코드 검증
                EmailVerificationService.VerifyResult result =
                        emailVerificationService.verifyCodeWithReason(request.email(), request.code());

                return switch (result) {
                    case SUCCESS -> ResponseEntity.ok(
                            Map.of(
                                    "verified", true,
                                    "message", "이메일 인증이 완료되었습니다."
                            )
                    );
                    case CODE_MISMATCH -> ResponseEntity.badRequest().body(
                            Map.of(
                                    "verified", false,
                                    "error", "CODE_MISMATCH",
                                    "message", "인증코드가 올바르지 않습니다."
                            )
                    );
                    case CODE_EXPIRED -> ResponseEntity.badRequest().body(
                            Map.of(
                                    "error", "CODE_EXPIRED",
                                    "message", "인증코드가 만료되었습니다. 다시 요청해주세요."
                            )
                    );
                    case ATTEMPTS_EXCEEDED -> ResponseEntity.badRequest().body(
                            Map.of(
                                    "verified", false,
                                    "error", "ATTEMPTS_EXCEEDED",
                                    "message", "입력 시도 횟수를 초과했습니다. 코드를 다시 받으세요."
                            )
                    );
                };
            }
        } catch (ApiException e) {
            ErrorCode code = e.getErrorCode();
            return ResponseEntity.status(code.getStatus())
                    .body(Map.of("error", code.getCode(), "message", e.getMessage()));
        }
    }
}
