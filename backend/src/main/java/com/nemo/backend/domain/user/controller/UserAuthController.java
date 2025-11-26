// com.nemo.backend.domain.user.controller.UserAuthController.java
package com.nemo.backend.domain.user.controller;

import com.nemo.backend.domain.auth.dto.LoginRequest;
import com.nemo.backend.domain.auth.dto.LoginResponse;
import com.nemo.backend.domain.auth.dto.SignUpRequest;
import com.nemo.backend.domain.auth.dto.SignUpResponse;
import com.nemo.backend.domain.auth.dto.RefreshRequest;
import com.nemo.backend.domain.auth.service.AuthService;
import com.nemo.backend.domain.auth.util.AuthExtractor;
import com.nemo.backend.domain.user.service.UserService;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping(
        value = "/api/users",
        produces = "application/json; charset=UTF-8"
)
@RequiredArgsConstructor
public class UserAuthController {

    private final AuthService authService;
    private final AuthExtractor authExtractor;
    private final UserService userService;

    // ---------------------------
    // 회원가입 (JSON)
    // ---------------------------
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

    // ---------------------------
    // 회원가입 (multipart – 프로필 이미지 업로드 포함)
    // ---------------------------
    @PostMapping(
            value = "/signup",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public ResponseEntity<SignUpResponse> signUpMultipart(
            @RequestPart("email") String email,
            @RequestPart("password") String password,
            @RequestPart("nickname") String nickname,  // ★ 필수
            @RequestPart(value = "image", required = false) MultipartFile image
    ) {
        if (nickname == null || nickname.isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "nickname 은 필수입니다.");
        }

        SignUpRequest request = new SignUpRequest();
        request.setEmail(email);
        request.setPassword(password);
        request.setNickname(nickname);

        if (image != null && !image.isEmpty()) {
            String profileUrl = userService.uploadProfileImageForSignup(image);
            request.setProfileImageUrl(profileUrl);
        }

        SignUpResponse response = authService.signUp(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .contentType(MediaType.APPLICATION_JSON)
                .body(response);
    }


    // ---------------------------
    // 로그인
    // ---------------------------
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

    // ---------------------------
    // 로그아웃 (명세 반영)
    //  - Body: { "refreshToken": "..." }
    // ---------------------------
    @PostMapping(
            value = "/logout",
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public ResponseEntity<Map<String, String>> logout(
            HttpServletRequest servletRequest,
            @RequestBody RefreshRequest body
    ) {
        String authorization = servletRequest.getHeader("Authorization");
        Long userId = authExtractor.extractUserId(authorization);

        if (body == null || body.refreshToken() == null || body.refreshToken().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "refreshToken 은 필수입니다.");
        }

        authService.logout(userId, body.refreshToken());

        return ResponseEntity.ok(Map.of("message", "성공적으로 로그아웃되었습니다."));
    }
}
