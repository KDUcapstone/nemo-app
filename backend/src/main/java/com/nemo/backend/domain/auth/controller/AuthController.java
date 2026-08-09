// backend/src/main/java/com/nemo/backend/domain/auth/controller/AuthController.java
package com.nemo.backend.domain.auth.controller;

import com.nemo.backend.domain.auth.dto.RefreshRequest;
import com.nemo.backend.domain.auth.dto.RefreshResponse;
import com.nemo.backend.domain.auth.service.AuthService;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import com.nemo.backend.domain.auth.dto.GoogleLoginRequest;
import com.nemo.backend.domain.auth.dto.KakaoLoginRequest;
import com.nemo.backend.domain.auth.dto.LoginResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping(
        value = "/api/auth",
        produces = "application/json; charset=UTF-8"
)
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    /**
     * ✅ JWT 갱신 API
     * POST /api/auth/refresh
     *
     * Request:
     * { "refreshToken": "..." }
     *
     * Response 200:
     * { "accessToken": "...", "refreshToken": "..."? }
     */
    @PostMapping("/refresh")
    public ResponseEntity<?> refresh(@RequestBody RefreshRequest request) {
        try {
            RefreshResponse res = authService.refresh(request);
            return ResponseEntity.ok(res);
        } catch (ApiException e) {
            ErrorCode code = e.getErrorCode();
            return ResponseEntity
                    .status(code.getStatus())
                    .body(new ErrorBody(code.getCode(), e.getMessage()));
        }
    }
    /**
     * 카카오 로그인
     * POST /api/auth/oauth/kakao
     */
    @PostMapping("/oauth/kakao")
    public ResponseEntity<?> kakaoLogin(@RequestBody KakaoLoginRequest request) {
        try {
            LoginResponse res = authService.loginWithKakao(request);
            return ResponseEntity.ok(res);
        } catch (ApiException e) {
            ErrorCode code = e.getErrorCode();
            return ResponseEntity
                    .status(code.getStatus())
                    .body(new ErrorBody(code.getCode(), e.getMessage()));
        }
    }

    /**
     * 구글 로그인
     * POST /api/auth/oauth/google
     */
    @PostMapping("/oauth/google")
    public ResponseEntity<?> googleLogin(@RequestBody GoogleLoginRequest request) {
        try {
            LoginResponse res = authService.loginWithGoogle(request);
            return ResponseEntity.ok(res);
        } catch (ApiException e) {
            ErrorCode code = e.getErrorCode();
            return ResponseEntity
                    .status(code.getStatus())
                    .body(new ErrorBody(code.getCode(), e.getMessage()));
        }
    }

    private record ErrorBody(String error, String message) {}
}
