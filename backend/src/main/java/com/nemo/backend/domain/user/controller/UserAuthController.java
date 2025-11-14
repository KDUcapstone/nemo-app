// backend/src/main/java/com/nemo/backend/domain/user/controller/UserAuthController.java
package com.nemo.backend.domain.user.controller;

import com.nemo.backend.domain.auth.dto.LoginRequest;
import com.nemo.backend.domain.auth.dto.LoginResponse;
import com.nemo.backend.domain.auth.dto.SignUpRequest;
import com.nemo.backend.domain.auth.dto.SignUpResponse;
import com.nemo.backend.domain.auth.service.AuthService;
import com.nemo.backend.domain.auth.util.AuthExtractor;       // ⭐ 공통 인증 유틸
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping(value = "/api/users", produces = MediaType.APPLICATION_JSON_VALUE)
@RequiredArgsConstructor // 🔥 final 필드 자동 생성자
public class UserAuthController {

    // --------------------------------------------------------
    // ⭐ 의존성 주입
    // --------------------------------------------------------
    private final AuthService authService;

    /**
     * 🔐 AuthExtractor
     * - Authorization 헤더에서 userId 추출하는 공통 로직 담당
     *   (JWT 검증 + RefreshToken 존재 여부까지)
     * - 다른 컨트롤러(Album, Photo 등)에서도 똑같이 사용 가능
     */
    private final AuthExtractor authExtractor;

    // ========================================================
    // 1) 회원가입
    // ========================================================
    @PostMapping(
            value = "/signup",
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public ResponseEntity<SignUpResponse> signUp(@RequestBody SignUpRequest request) {
        SignUpResponse response = authService.signUp(request);
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .contentType(MediaType.APPLICATION_JSON)
                .body(response);
    }

    // ========================================================
    // 2) 로그인
    //    - 실제 토큰 발급은 AuthService.login() 내부에서 처리
    // ========================================================
    @PostMapping(
            value = "/login",
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public ResponseEntity<LoginResponse> login(@RequestBody LoginRequest request) {
        LoginResponse body = authService.login(request);
        return ResponseEntity
                .ok()
                .contentType(MediaType.APPLICATION_JSON)
                .body(body);
    }

    // ========================================================
    // 3) 로그아웃
    //    - AccessToken에서 userId 추출 → 해당 유저의 RefreshToken 삭제
    //    - 인증 체크(토큰 유효 + RefreshToken 존재 여부)는 AuthExtractor가 담당
    // ========================================================
    @PostMapping(value = "/logout", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String,String>> logout(HttpServletRequest request) {
        // 1) 헤더에서 Authorization 꺼내기
        String authorization = request.getHeader("Authorization");

        // 2) 공통 유틸로 userId 추출 (JWT + RefreshToken 검증 포함)
        Long userId = authExtractor.extractUserId(authorization);

        // 3) 실제 로그아웃 처리 (RefreshToken 삭제)
        authService.logout(userId);

        // 4) JSON 메시지로 응답 (204 대신 200 OK + body)
        return ResponseEntity.ok(Map.of("message", "logged out"));
    }
}
