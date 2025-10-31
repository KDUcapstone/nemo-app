// backend/src/main/java/com/nemo/backend/domain/auth/service/AuthService.java
package com.nemo.backend.domain.auth.service;

import com.nemo.backend.domain.auth.dto.LoginRequest;
import com.nemo.backend.domain.auth.dto.LoginResponse;
import com.nemo.backend.domain.auth.dto.SignUpRequest;
import com.nemo.backend.domain.auth.dto.SignUpResponse;
import com.nemo.backend.domain.auth.jwt.JwtTokenProvider;
import com.nemo.backend.domain.auth.token.RefreshToken;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Service
@Transactional
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    public AuthService(UserRepository userRepository,
                       RefreshTokenRepository refreshTokenRepository,
                       PasswordEncoder passwordEncoder,
                       JwtTokenProvider jwtTokenProvider) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    // ========== SIGN UP ==========
    public SignUpResponse signUp(SignUpRequest request) {
        if (request.getEmail() == null || request.getEmail().isBlank()) {
            throw new IllegalArgumentException("이메일은 필수입니다.");
        }
        if (request.getPassword() == null || request.getPassword().isBlank()) {
            throw new IllegalArgumentException("비밀번호는 필수입니다.");
        }
        // existsByEmail 없으면 findByEmail().isPresent()로 대체
        // ✅ 올바른 코드 (한 줄로 끝)
        boolean exists = userRepository.existsByEmail(request.getEmail());

        if (exists) {
            throw new IllegalArgumentException("이미 가입된 이메일입니다.");
        }

        // ★ 빌더 대신 기본 생성자 + setter
        User user = new User();
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        // 프로젝트 필드명에 맞게 채우기 (없으면 무시됨)
        try {
            // nickname
            var f1 = User.class.getDeclaredField("nickname");
            f1.setAccessible(true);
            f1.set(user, request.getNickname()); // SignUpRequest에 nickname 없으면 getName() 등으로 매핑
        } catch (NoSuchFieldException ignored) {}
        catch (Exception e) { throw new RuntimeException(e); }

        try {
            // profileImageUrl 기본 null
            var f2 = User.class.getDeclaredField("profileImageUrl");
            f2.setAccessible(true);
            if (f2.get(user) == null) f2.set(user, null);
        } catch (NoSuchFieldException ignored) {}
        catch (Exception e) { throw new RuntimeException(e); }

        try {
            // provider 기본 "local"
            var f3 = User.class.getDeclaredField("provider");
            f3.setAccessible(true);
            if (f3.get(user) == null) f3.set(user, "local");
        } catch (NoSuchFieldException ignored) {}
        catch (Exception e) { throw new RuntimeException(e); }

        try {
            // socialId 기본 null
            var f4 = User.class.getDeclaredField("socialId");
            f4.setAccessible(true);
            if (f4.get(user) == null) f4.set(user, null);
        } catch (NoSuchFieldException ignored) {}
        catch (Exception e) { throw new RuntimeException(e); }

        User saved = userRepository.save(user);
        return new SignUpResponse(saved.getId(), saved.getEmail(),
                // 요청 필드 명에 맞춰 반환
                getSafeNickname(saved), getSafeProfile(saved));
    }

    // ========== LOGIN ==========
    public LoginResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new IllegalArgumentException("가입되지 않은 이메일입니다."));
        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new IllegalArgumentException("비밀번호가 일치하지 않습니다.");
        }

        // 액세스 토큰
        String accessToken = jwtTokenProvider.generateAccessToken(user);

        // 리프레시 토큰(2주)
        String refreshTokenStr = UUID.randomUUID().toString();
        LocalDateTime expiry = LocalDateTime.now().plusDays(14);

        Optional<RefreshToken> existing = refreshTokenRepository.findFirstByUserId(user.getId());
        RefreshToken tokenEntity = existing.orElseGet(RefreshToken::new);
        tokenEntity.setUserId(user.getId());
        tokenEntity.setToken(refreshTokenStr);
        tokenEntity.setExpiry(expiry); // 엔티티가 expiry 필드 사용

        refreshTokenRepository.save(tokenEntity);

        // AuthService.login() 마지막 한 줄
        return new LoginResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),         // null이면 생성자에서 ""로
                user.getProfileImageUrl(),  // null이면 생성자에서 ""로
                accessToken,
                refreshTokenStr
        );


    }

    // ========== LOGOUT ==========
    public void logout(Long userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }

    // ========== DELETE ACCOUNT ==========
    public void deleteAccount(Long userId) {
        deleteAccount(userId, null);
    }

    public void deleteAccount(Long userId, String rawPassword) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("해당 사용자를 찾을 수 없습니다."));

        if (rawPassword == null || rawPassword.isBlank()
                || !passwordEncoder.matches(rawPassword, user.getPassword())) {
            throw new IllegalArgumentException("비밀번호가 일치하지 않습니다.");
        }

        refreshTokenRepository.deleteByUserId(userId);
        userRepository.delete(user);
    }

    // ===== 내부 헬퍼 =====
    private String getSafeNickname(User user) {
        try {
            var f = User.class.getDeclaredField("nickname");
            f.setAccessible(true);
            Object v = f.get(user);
            return v != null ? v.toString() : null;
        } catch (Exception e) { return null; }
    }

    private String getSafeProfile(User user) {
        try {
            var f = User.class.getDeclaredField("profileImageUrl");
            f.setAccessible(true);
            Object v = f.get(user);
            return v != null ? v.toString() : null;
        } catch (Exception e) { return null; }
    }
}
