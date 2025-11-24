// backend/src/main/java/com/nemo/backend/domain/auth/service/PasswordResetService.java
package com.nemo.backend.domain.auth.service;

import com.nemo.backend.domain.auth.dto.PasswordCodeRequest;
import com.nemo.backend.domain.auth.dto.PasswordCodeVerifyRequest;
import com.nemo.backend.domain.auth.dto.PasswordResetRequest;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
public class PasswordResetService {

    private final EmailVerificationService emailVerificationService;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    private static final Duration RESET_TOKEN_TTL = Duration.ofMinutes(10);

    private final Map<String, ResetTokenInfo> resetTokens = new ConcurrentHashMap<>();

    @Getter
    private static class ResetTokenInfo {
        private final String email;
        private final LocalDateTime expiresAt;
        private boolean used;

        ResetTokenInfo(String email, LocalDateTime expiresAt) {
            this.email = email;
            this.expiresAt = expiresAt;
            this.used = false;
        }

        boolean isExpired() {
            return expiresAt.isBefore(LocalDateTime.now());
        }

        void markUsed() { this.used = true; }

        boolean isUsable() { return !used && !isExpired(); }
    }

    /** 1) 비밀번호 분실: 인증코드 발송 */
    public void sendPasswordResetCode(PasswordCodeRequest req) {
        // 가입 여부와 관계없이 항상 성공 응답(계정 유추 방지)
        if (req == null || req.email() == null) {
            throw new ApiException(ErrorCode.INVALID_EMAIL_FORMAT);
        }
        emailVerificationService.sendVerificationCode(req.email());
    }

    /** 2) 인증코드 검증 → resetToken 발급 */
    public ResetTokenResult verifyCodeAndIssueToken(PasswordCodeVerifyRequest req) {
        EmailVerificationService.VerifyResult result =
                emailVerificationService.verifyCodeWithReason(req.email(), req.code());

        return switch (result) {
            case SUCCESS -> {
                String token = "rt_" + UUID.randomUUID();
                LocalDateTime now = LocalDateTime.now();
                resetTokens.put(token, new ResetTokenInfo(req.email(), now.plus(RESET_TOKEN_TTL)));

                yield new ResetTokenResult(true, token, (int) RESET_TOKEN_TTL.getSeconds());
            }
            case CODE_MISMATCH -> throw new ApiException(ErrorCode.CODE_MISMATCH);
            case CODE_EXPIRED -> throw new ApiException(ErrorCode.CODE_EXPIRED);
            case ATTEMPTS_EXCEEDED -> throw new ApiException(ErrorCode.ATTEMPTS_EXCEEDED);
        };
    }

    /** 3) resetToken 으로 새 비밀번호 설정 */
    public void resetPassword(PasswordResetRequest req) {
        if (req == null
                || req.resetToken() == null
                || req.resetToken().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_RESET_TOKEN);
        }

        if (!req.newPassword().equals(req.confirmPassword())) {
            throw new ApiException(ErrorCode.PASSWORD_CONFIRM_MISMATCH);
        }

        if (!isValidPassword(req.newPassword())) {
            throw new ApiException(ErrorCode.PASSWORD_POLICY_VIOLATION);
        }

        ResetTokenInfo info = resetTokens.get(req.resetToken());
        if (info == null || !info.isUsable()) {
            throw new ApiException(ErrorCode.INVALID_RESET_TOKEN);
        }

        String email = info.getEmail();

        // 사용자 조회 (계정 유무 에러 메시지는 노출하지 않음)
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_RESET_TOKEN));

        user.setPassword(passwordEncoder.encode(req.newPassword()));
        userRepository.save(user);

        // 토큰 1회용 처리
        info.markUsed();
    }

    private boolean isValidPassword(String pw) {
        if (pw == null || pw.length() < 8 || pw.length() > 64) return false;
        boolean hasLetter = pw.chars().anyMatch(Character::isLetter);
        boolean hasDigit = pw.chars().anyMatch(Character::isDigit);
        boolean hasSpecial = pw.chars().anyMatch(c -> !Character.isLetterOrDigit(c));
        int kinds = (hasLetter ? 1 : 0) + (hasDigit ? 1 : 0) + (hasSpecial ? 1 : 0);
        return kinds >= 2;
    }

    public record ResetTokenResult(
            boolean verified,
            String resetToken,
            int expiresIn
    ) {}
}
