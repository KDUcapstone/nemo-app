package com.nemo.backend.domain.auth.controller;

import com.nemo.backend.domain.auth.dto.RefreshRequest;
import com.nemo.backend.domain.auth.dto.RefreshResponse;
import com.nemo.backend.domain.auth.service.AuthService;
import com.nemo.backend.global.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/refresh")
    public ResponseEntity<?> refresh(@RequestBody RefreshRequest request) {
        try {
            RefreshResponse res = authService.refresh(request);
            return ResponseEntity.ok(res);
        } catch (ApiException e) {
            return ResponseEntity.status(e.getErrorCode().getHttpStatus())
                    .body(new Error("INVALID_REFRESH", "리프레시 토큰이 유효하지 않거나 만료되었습니다."));
        }
    }

    private record Error(String error, String message) {}
}
