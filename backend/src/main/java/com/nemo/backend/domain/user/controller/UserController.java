// backend/src/main/java/com/nemo/backend/domain/user/controller/UserController.java
package com.nemo.backend.domain.user.controller;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.nemo.backend.domain.auth.dto.DeleteAccountRequest;
import com.nemo.backend.domain.auth.service.AuthService;
import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final AuthService authService;
    private final JwtTokenProvider jwtTokenProvider;

    public UserController(AuthService authService, JwtTokenProvider jwtTokenProvider) {
        this.authService = authService;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    /**
     * 현재 로그인한 사용자의 계정을 삭제한다.
     * 프론트는 JSON body로 { "password": "..." } 형태를 보내며,
     * 백엔드는 토큰에서 사용자 ID를 추출하고 비밀번호를 검증한다.
     */
    @DeleteMapping("/me")
    public ResponseEntity<?> deleteMe(@Valid @RequestBody DeleteAccountRequest body,
                                      HttpServletRequest httpRequest) {
        String token = jwtTokenProvider.resolveToken(httpRequest);
        if (token == null || !jwtTokenProvider.validateToken(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("유효하지 않은 토큰입니다.");
        }

        Long userId = jwtTokenProvider.getUserId(token);
        authService.deleteAccount(userId, body.getPassword());
        return ResponseEntity.ok("회원탈퇴 완료");
    }
}
