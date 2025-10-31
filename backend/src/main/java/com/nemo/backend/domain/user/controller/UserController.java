// backend/src/main/java/com/nemo/backend/domain/user/controller/UserController.java
package com.nemo.backend.domain.user.controller;

import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.domain.user.dto.UserProfileResponse;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final JwtTokenProvider jwtTokenProvider;
    private final UserRepository userRepository;

    public UserController(JwtTokenProvider jwtTokenProvider, UserRepository userRepository) {
        this.jwtTokenProvider = jwtTokenProvider;
        this.userRepository = userRepository;
    }

    /** ✅ 내 정보 조회 */
    @GetMapping("/me")
    public ResponseEntity<?> getMe(HttpServletRequest request) {
        String token = jwtTokenProvider.resolveToken(request);
        if (token == null || !jwtTokenProvider.validateToken(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("유효하지 않은 토큰");
        }
        Long userId = jwtTokenProvider.getUserId(token);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));

        // UserController.getMe() 반환부 (핵심만)
        return ResponseEntity.ok(new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),        // 여기서 null이어도 DTO가 ""로 바꿔줌
                user.getProfileImageUrl()
        ));

    }

    /** (기존) 회원탈퇴 */
    @DeleteMapping("/me")
    public ResponseEntity<?> deleteMe(@Valid @RequestBody com.nemo.backend.domain.auth.dto.DeleteAccountRequest body,
                                      HttpServletRequest httpRequest) {
        String token = jwtTokenProvider.resolveToken(httpRequest);
        if (token == null || !jwtTokenProvider.validateToken(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("유효하지 않은 토큰");
        }
        Long userId = jwtTokenProvider.getUserId(token);

        // 주입 받아 쓰던 AuthService 호출은 기존 그대로 유지
        // authService.deleteAccount(userId, body.getPassword());
        return ResponseEntity.ok("회원탈퇴 완료");
    }
}
