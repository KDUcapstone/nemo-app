// com.nemo.backend.domain.user.controller.UserController

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

import java.nio.charset.StandardCharsets;
import java.util.Map;

@RestController
@RequestMapping(
        value = "/api/users",
        produces = "application/json; charset=UTF-8")
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
    // 2-1) 내 정보 수정 (JSON, PUT /api/users/me)
    //    - Body: { nickname, profileImageUrl }
    // ========================================================
    @PutMapping(value = "/me", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> updateMeJson(
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
    // 2-2) 내 정보 수정 (multipart/form-data, PUT /api/users/me)
    //    - field:
    //        nickname: 텍스트 (옵션)
    //        image:    파일   (옵션)
    // ========================================================
    @PutMapping(
            value = "/me",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public ResponseEntity<Map<String, Object>> updateMeMultipart(
            HttpServletRequest request,
            @RequestPart(value = "nickname", required = false) String rawNickname,
            @RequestPart(value = "image", required = false) MultipartFile image
    ) {
        String authorization = request.getHeader("Authorization");
        Long userId = authExtractor.extractUserId(authorization);

        // 🔤 multipart 한글 깨짐 방지: ISO-8859-1 → UTF-8 재변환
        String nickname = decodeIfIso8859(rawNickname);

        User updated = userService.updateProfileMultipart(userId, nickname, image);

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
    // 3) (선택) 프로필 이미지 전용 업로드
    //    - 프론트가 쓰기 싫으면 안 써도 됨
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

        return ResponseEntity.ok(Map.of("message", "회원탈퇴가 정상적으로 처리되었습니다."));
    }

    // ========================================================
    // 내부 유틸: ISO-8859-1 로 잘못 디코딩된 문자열을 UTF-8 로 복원
    // ========================================================
    private String decodeIfIso8859(String value) {
        if (value == null || value.isBlank()) return value;

        // 이미 한글이 제대로 들어온 경우(Hangul 영역) 그냥 리턴
        boolean hasHangul = value.codePoints()
                .anyMatch(cp ->
                        (cp >= 0xAC00 && cp <= 0xD7AF) || // Hangul Syllables
                                (cp >= 0x1100 && cp <= 0x11FF));  // Hangul Jamo

        if (hasHangul) {
            return value;
        }

        // C1 영역(0xC0~0xFF) 글자가 많이 포함돼 있으면 모지바케로 간주하고 재디코딩
        long suspicious = value.chars()
                .filter(ch -> ch >= 0xC0 && ch <= 0xFF)
                .count();

        if (suspicious == 0) {
            return value;
        }

        byte[] isoBytes = value.getBytes(StandardCharsets.ISO_8859_1);
        return new String(isoBytes, StandardCharsets.UTF_8);
    }
}
