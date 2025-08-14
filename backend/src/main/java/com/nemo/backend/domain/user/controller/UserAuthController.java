package com.nemo.backend.domain.user.controller;

import com.nemo.backend.domain.auth.dto.*;
import com.nemo.backend.domain.auth.service.AuthService;
import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;

/**
 * Controller hosted under the user domain that exposes authentication
 * endpoints.  This indirection allows us to avoid touching the auth
 * controller paths (/api/auth) while still delegating to {@link AuthService}
 * for the underlying business logic.
 */
@RestController
@RequestMapping("/api/users")
public class UserAuthController {
    private final AuthService authService;
    private final JwtTokenProvider jwtTokenProvider;

    public UserAuthController(AuthService authService, JwtTokenProvider jwtTokenProvider) {
        this.authService = authService;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    @PostMapping("/signup")
    public ResponseEntity<SignUpResponse> signUp(@RequestBody SignUpRequest request) {
        SignUpResponse response = authService.signUp(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@RequestBody LoginRequest request) {
        LoginResponse response = authService.login(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(HttpServletRequest request) {
        Long userId = extractUserId(request);
        authService.logout(userId);
        return ResponseEntity.noContent().build();
    }

    private Long extractUserId(HttpServletRequest request) {
        String authorization = request.getHeader("Authorization");
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }
        String token = authorization.substring(7);
        if (!jwtTokenProvider.validateToken(token)) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }
        return jwtTokenProvider.getUserId(token);
    }
}