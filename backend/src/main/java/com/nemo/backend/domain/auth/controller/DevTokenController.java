// backend/src/main/java/com/nemo/backend/domain/auth/controller/DevTokenController.java
package com.nemo.backend.domain.auth.controller;

import com.nemo.backend.domain.auth.jwt.JwtUtil;                     // ★ 변경
import com.nemo.backend.domain.auth.token.RefreshToken;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

@Profile({"local","dev"})
@RestController
@RequestMapping("/api/auth/dev")
@RequiredArgsConstructor
public class DevTokenController {

    private final JwtUtil jwtUtil;                                   // ★ 변경
    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;

    /**
     * 예) POST /api/auth/dev/seed?userId=4
     * - userId가 있으면 해당 사용자 재사용
     * - 없으면 email 기준으로 조회 후 없으면 생성
     * - refresh 토큰은 upsert
     * - access 토큰 생성 후 반환
     */
    @PostMapping("/seed")
    @Transactional
    public ResponseEntity<SeedResponse> seed(
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false, defaultValue = "demo4@nemo.app") String email
    ) {
        // 1) 사용자 찾기 (id 우선, 없으면 email)
        User user = null;
        if (userId != null) {
            user = userRepository.findById(userId).orElse(null);
        }
        if (user == null) {
            user = userRepository.findByEmail(email).orElse(null);
        }
        // 2) 없으면 생성
        if (user == null) {
            user = new User();
            user.setEmail(email);
            user.setNickname(email.split("@")[0]);
            user.setProvider("LOCAL");
            user = userRepository.save(user);
        }

        // 3) refresh 토큰 upsert
        RefreshToken refresh = refreshTokenRepository.findFirstByUserId(user.getId())
                .orElseGet(RefreshToken::new);
        refresh.setUserId(user.getId());
        refresh.setToken("dev-refresh-token-" + user.getId());
        refresh.setExpiry(LocalDateTime.now().plusDays(7));
        refreshTokenRepository.save(refresh);

        // 4) ★ access 토큰 발급을 JwtUtil로 통일
        String access = jwtUtil.createAccessToken(user.getId(), user.getEmail());

        return ResponseEntity.ok(new SeedResponse(
                user.getId(),
                user.getEmail(),
                access,
                refresh.getToken(),
                refresh.getExpiry()
        ));
    }

    public record SeedResponse(Long userId, String email, String accessToken, String refreshToken,
                               LocalDateTime refreshExpiry) {}
}
