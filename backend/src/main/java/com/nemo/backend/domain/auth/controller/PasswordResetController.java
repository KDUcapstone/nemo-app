// backend/src/main/java/com/nemo/backend/domain/auth/controller/PasswordResetController.java
package com.nemo.backend.domain.auth.controller;

import com.nemo.backend.domain.auth.dto.PasswordCodeRequest;
import com.nemo.backend.domain.auth.dto.PasswordCodeVerifyRequest;
import com.nemo.backend.domain.auth.dto.PasswordResetRequest;
import com.nemo.backend.domain.auth.service.PasswordResetService;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping(
        value = "/api/auth/password",
        produces = "application/json; charset=UTF-8"
)
@RequiredArgsConstructor
public class PasswordResetController {

    private final PasswordResetService passwordResetService;

    /**
     * 1) 비밀번호 분실 시: 인증코드 발송
     * POST /api/auth/password/code
     */
    @PostMapping("/code")
    public ResponseEntity<?> sendCode(@RequestBody PasswordCodeRequest req) {
        try {
            passwordResetService.sendPasswordResetCode(req);
            return ResponseEntity.ok(
                    Map.of("message", "입력하신 이메일로 인증코드를 전송했습니다. 5분 안에 입력해주세요.")
            );
        } catch (ApiException e) {
            ErrorCode code = e.getErrorCode();
            return ResponseEntity.status(code.getStatus())
                    .body(Map.of("error", code.getCode(), "message", e.getMessage()));
        }
    }

    /**
     * 2) 비밀번호 분실 시: 인증코드 확인(토큰 발급)
     * POST /api/auth/password/code/verify
     */
    @PostMapping("/code/verify")
    public ResponseEntity<?> verifyCode(@RequestBody PasswordCodeVerifyRequest req) {
        try {
            PasswordResetService.ResetTokenResult result =
                    passwordResetService.verifyCodeAndIssueToken(req);

            return ResponseEntity.ok(
                    Map.of(
                            "verified", result.verified(),
                            "resetToken", result.resetToken(),
                            "expiresIn", result.expiresIn()
                    )
            );
        } catch (ApiException e) {
            ErrorCode code = e.getErrorCode();
            return ResponseEntity.status(code.getStatus())
                    .body(Map.of(
                            "verified", false,
                            "error", code.getCode(),
                            "message", e.getMessage()
                    ));
        }
    }

    /**
     * 3) 비밀번호 분실 시: 새 비밀번호 설정
     * POST /api/auth/password/reset
     */
    @PostMapping("/reset")
    public ResponseEntity<?> reset(@RequestBody PasswordResetRequest req) {
        try {
            passwordResetService.resetPassword(req);
            return ResponseEntity.ok(
                    Map.of("message", "비밀번호가 변경되었습니다. 새 비밀번호로 로그인해주세요.")
            );
        } catch (ApiException e) {
            ErrorCode code = e.getErrorCode();
            return ResponseEntity.status(code.getStatus())
                    .body(Map.of("error", code.getCode(), "message", e.getMessage()));
        }
    }
}
