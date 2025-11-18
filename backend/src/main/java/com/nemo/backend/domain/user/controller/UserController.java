package com.nemo.backend.domain.user.controller;

import com.nemo.backend.domain.auth.dto.DeleteAccountRequest;
import com.nemo.backend.domain.auth.service.AuthService;
import com.nemo.backend.domain.auth.util.AuthExtractor;
import com.nemo.backend.domain.user.dto.UpdateUserRequest;
import com.nemo.backend.domain.user.dto.UserProfileResponse;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.domain.user.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping(value = "/api/users", produces = MediaType.APPLICATION_JSON_VALUE)
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;
    private final AuthService authService;
    private final AuthExtractor authExtractor;
    private final UserService userService;

    // ========================================================
    // 1) 내 정보 조회 (GET /api/users/me)
    // ========================================================
    @GetMapping("/me")
    public ResponseEntity<UserProfileResponse> getMe(HttpServletRequest request) {

        String authorization = request.getHeader("Authorization");
        Long userId = authExtractor.extractUserId(authorization);

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));

        UserProfileResponse body = new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.getCreatedAt()
        );

        return ResponseEntity.ok(body);
    }

    // ========================================================
    // 2) 내 정보 수정 (PUT /api/users/me)
    //    - JSON Body: { nickname, profileImageUrl }
    // ========================================================
    @PutMapping(value = "/me", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> updateMe(
            HttpServletRequest request,
            @RequestBody UpdateUserRequest updateRequest
    ) {
        String authorization = request.getHeader("Authorization");
        Long userId = authExtractor.extractUserId(authorization);

        User updated = userService.updateProfile(userId, updateRequest);

        UserProfileResponse profile = new UserProfileResponse(
                updated.getId(),
                updated.getEmail(),
                updated.getNickname(),
                updated.getProfileImageUrl(),
                updated.getCreatedAt()
        );

        return ResponseEntity.ok(Map.of(
                "userId", profile.getUserId(),
                "email", profile.getEmail(),
                "nickname", profile.getNickname(),
                "profileImageUrl", profile.getProfileImageUrl(),
                "updatedAt", profile.getCreatedAt()
        ));
    }

    // ========================================================
    // 3) 프로필 이미지 업로드 (POST /api/users/me/profile-image)
    //    - multipart/form-data
    //    - field name: image
    // ========================================================
    @PostMapping(
            value = "/me/profile-image",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public ResponseEntity<Map<String, String>> uploadProfileImage(
            HttpServletRequest request,
            @RequestPart("image") MultipartFile image
    ) {
        String authorization = request.getHeader("Authorization");
        Long userId = authExtractor.extractUserId(authorization);

        String profileUrl = userService.uploadProfileImage(userId, image);

        return ResponseEntity.ok(Map.of(
                "profileImageUrl", profileUrl,
                "message", "프로필 이미지가 성공적으로 업로드되었습니다."
        ));
    }

    // ========================================================
    // 4) 회원탈퇴 (DELETE /api/users/me)
    // ========================================================
    @DeleteMapping(value = "/me", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, String>> deleteMe(
            @Valid @RequestBody DeleteAccountRequest body,
            HttpServletRequest httpRequest
    ) {
        String authorization = httpRequest.getHeader("Authorization");
        Long userId = authExtractor.extractUserId(authorization);

        authService.deleteAccount(userId, body.getPassword());

        return ResponseEntity.ok(Map.of("message", "회원탈퇴 완료"));
    }
}
