package com.nemo.backend.domain.user.controller;

import com.nemo.backend.domain.auth.dto.DeleteAccountRequest;
import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.domain.auth.service.AuthService;
import com.nemo.backend.domain.user.dto.UserProfileResponse;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;

import java.util.Map;

@RestController
@RequestMapping(value = "/api/users", produces = MediaType.APPLICATION_JSON_VALUE)
public class UserController {

    private final JwtTokenProvider jwtTokenProvider;
    private final UserRepository userRepository;
    private final AuthService authService;

    public UserController(JwtTokenProvider jwtTokenProvider,
                          UserRepository userRepository,
                          AuthService authService) {
        this.jwtTokenProvider = jwtTokenProvider;
        this.userRepository = userRepository;
        this.authService = authService;
    }

    // 내 정보 조회
    @GetMapping(value = "/me", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> getMe(HttpServletRequest request) {
        String token = jwtTokenProvider.resolveToken(request);
        if (token == null || !jwtTokenProvider.validateToken(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("message", "유효하지 않은 토큰"));
        }
        Long userId = jwtTokenProvider.getUserId(token);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));

        UserProfileResponse body = new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.getCreatedAt()   // BaseEntity에서 상속받음
        );
        return ResponseEntity.ok().body(body);
    }


    // 회원탈퇴 (비밀번호 검증)
    @DeleteMapping(value = "/me", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> deleteMe(@Valid @RequestBody DeleteAccountRequest body,
                                      HttpServletRequest httpRequest) {
        String token = jwtTokenProvider.resolveToken(httpRequest);
        if (token == null || !jwtTokenProvider.validateToken(token)) {
            return ResponseEntity
                    .status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("message", "유효하지 않은 토큰"));
        }

        Long userId = jwtTokenProvider.getUserId(token);
        authService.deleteAccount(userId, body.getPassword());

        return ResponseEntity.ok(Map.of("message", "회원탈퇴 완료"));
    }
}
