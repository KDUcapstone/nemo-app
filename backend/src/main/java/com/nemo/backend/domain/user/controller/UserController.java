// backend/src/main/java/com/nemo/backend/domain/user/controller/UserController.java
package com.nemo.backend.domain.user.controller;

import com.nemo.backend.domain.auth.dto.DeleteAccountRequest;
import com.nemo.backend.domain.auth.service.AuthService;
import com.nemo.backend.domain.auth.util.AuthExtractor;      // 🔐 공통 인증 유틸
import com.nemo.backend.domain.user.dto.UserProfileResponse;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping(value = "/api/users", produces = MediaType.APPLICATION_JSON_VALUE)
@RequiredArgsConstructor // ⭐ final 필드 자동 생성자 주입
public class UserController {

    // --------------------------------------------------------
    // ⭐ 의존성 주입
    // --------------------------------------------------------
    private final UserRepository userRepository;
    private final AuthService authService;

    /**
     * 🔐 AuthExtractor
     * - Authorization 헤더에서 userId를 꺼내는 공통 로직
     *   (JWT 검증 + RefreshToken 존재 여부까지 포함)
     * - UserAuthController, AlbumController, PhotoController와 동일하게 사용
     */
    private final AuthExtractor authExtractor;

    // ========================================================
    // 1) 내 정보 조회 (GET /api/users/me)
    // ========================================================
    @GetMapping(value = "/me", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<UserProfileResponse> getMe(HttpServletRequest request) {

        // 1) Authorization 헤더에서 userId 추출
        String authorization = request.getHeader("Authorization");
        Long userId = authExtractor.extractUserId(authorization);

        // 2) DB에서 사용자 정보 조회
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));

        // 3) 프로필 응답 DTO로 변환
        UserProfileResponse body = new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.getCreatedAt()   // BaseEntity에서 상속받음
        );

        return ResponseEntity.ok(body);
    }

    // ========================================================
    // 2) 회원탈퇴 (DELETE /api/users/me)
    //    - 비밀번호 검증 + 계정/리프레시 토큰 삭제
    // ========================================================
    @DeleteMapping(value = "/me", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, String>> deleteMe(
            @Valid @RequestBody DeleteAccountRequest body,
            HttpServletRequest httpRequest
    ) {
        // 1) Authorization 헤더에서 userId 추출 (JWT + RefreshToken 검증 포함)
        String authorization = httpRequest.getHeader("Authorization");
        Long userId = authExtractor.extractUserId(authorization);

        // 2) 비밀번호 검증 + 실제 탈퇴 처리 (AuthService에 위임)
        authService.deleteAccount(userId, body.getPassword());

        // 3) 결과 메시지 반환
        return ResponseEntity.ok(Map.of("message", "회원탈퇴 완료"));
    }
}
