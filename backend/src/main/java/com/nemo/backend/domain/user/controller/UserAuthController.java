// backend/src/main/java/com/nemo/backend/domain/user/controller/UserAuthController.java
package com.nemo.backend.domain.user.controller;

import com.nemo.backend.domain.auth.dto.LoginRequest;
import com.nemo.backend.domain.auth.dto.LoginResponse;
import com.nemo.backend.domain.auth.dto.SignUpRequest;
import com.nemo.backend.domain.auth.dto.SignUpResponse;
import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.domain.auth.service.AuthService;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping(value = "/api/users", produces = MediaType.APPLICATION_JSON_VALUE)
public class UserAuthController {
    private final AuthService authService;
    private final JwtTokenProvider jwtTokenProvider;
    private final RefreshTokenRepository refreshTokenRepository;

    public UserAuthController(AuthService authService,
                              JwtTokenProvider jwtTokenProvider,
                              RefreshTokenRepository refreshTokenRepository) {
        this.authService = authService;
        this.jwtTokenProvider = jwtTokenProvider;
        this.refreshTokenRepository = refreshTokenRepository;
    }

    @PostMapping(value = "/signup",
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<SignUpResponse> signUp(@RequestBody SignUpRequest request) {
        SignUpResponse response = authService.signUp(request);
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .contentType(MediaType.APPLICATION_JSON)  // ✅ Content-Type 강제
                .body(response);
    }


    @PostMapping(
            value = "/login",
            consumes = org.springframework.http.MediaType.APPLICATION_JSON_VALUE,
            produces = org.springframework.http.MediaType.APPLICATION_JSON_VALUE
    )
    public org.springframework.http.ResponseEntity<LoginResponse> login(@RequestBody LoginRequest request) {
        LoginResponse body = authService.login(request);
        return org.springframework.http.ResponseEntity
                .ok()
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .body(body);
    }



    @PostMapping(value = "/logout", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String,String>> logout(HttpServletRequest request) {
        Long userId = extractUserId(request);
        authService.logout(userId);
        // 204는 JSON과 충돌 날 수 있어 200으로 통일
        return ResponseEntity.ok(Map.of("message", "logged out"));
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
        Long userId = jwtTokenProvider.getUserId(token);

        boolean hasRefresh = refreshTokenRepository.findFirstByUserId(userId).isPresent();
        if (!hasRefresh) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }
        return userId;
    }
}
