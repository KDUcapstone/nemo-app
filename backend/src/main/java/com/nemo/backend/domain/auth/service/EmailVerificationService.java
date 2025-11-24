// backend/src/main/java/com/nemo/backend/domain/auth/service/EmailVerificationService.java
package com.nemo.backend.domain.auth.service;

import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ClassPathResource;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ThreadLocalRandom;

@Service
@RequiredArgsConstructor
public class EmailVerificationService {

    private final JavaMailSender mailSender;

    // email -> 코드 정보
    private final Map<String, CodeInfo> verificationCodes = new ConcurrentHashMap<>();

    // 설정값 (명세 기준)
    private static final Duration CODE_TTL = Duration.ofMinutes(5);  // 유효 5분
    private static final int MAX_ATTEMPTS = 5;                        // 최대 5회 시도
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60); // 60초 쿨다운

    public enum VerifyResult {
        SUCCESS,
        CODE_MISMATCH,
        CODE_EXPIRED,
        ATTEMPTS_EXCEEDED
    }

    private static class CodeInfo {
        final String code;
        final LocalDateTime expiresAt;
        LocalDateTime lastSentAt;
        int attempts;

        CodeInfo(String code, LocalDateTime expiresAt, LocalDateTime lastSentAt) {
            this.code = code;
            this.expiresAt = expiresAt;
            this.lastSentAt = lastSentAt;
            this.attempts = 0;
        }
    }

    /** ✅ 인증코드 발송 */
    public void sendVerificationCode(String email) {
        if (!isValidEmail(email)) {
            throw new ApiException(ErrorCode.INVALID_EMAIL_FORMAT);
        }

        LocalDateTime now = LocalDateTime.now();

        CodeInfo existing = verificationCodes.get(email);
        if (existing != null && existing.lastSentAt != null) {
            if (Duration.between(existing.lastSentAt, now).compareTo(RESEND_COOLDOWN) < 0) {
                // 429 RATE_LIMITED
                throw new ApiException(ErrorCode.RATE_LIMITED);
            }
        }

        String code = generateCode();
        CodeInfo info = new CodeInfo(code, now.plus(CODE_TTL), now);
        verificationCodes.put(email, info);

        try {
            sendMail(email, code);
        } catch (Exception e) {
            throw new ApiException(ErrorCode.MAIL_SEND_FAILED, "인증코드 메일을 보내지 못했습니다.");
        }
    }

    /** ✅ 코드 검증 (사유까지 리턴) */
    public VerifyResult verifyCodeWithReason(String email, String code) {
        CodeInfo info = verificationCodes.get(email);
        LocalDateTime now = LocalDateTime.now();

        if (info == null || info.expiresAt.isBefore(now)) {
            verificationCodes.remove(email);
            return VerifyResult.CODE_EXPIRED;
        }

        if (!info.code.equals(code)) {
            info.attempts++;
            if (info.attempts >= MAX_ATTEMPTS) {
                verificationCodes.remove(email);
                return VerifyResult.ATTEMPTS_EXCEEDED;
            }
            return VerifyResult.CODE_MISMATCH;
        }

        // 성공 시 1회성으로 제거
        verificationCodes.remove(email);
        return VerifyResult.SUCCESS;
    }

    /** 기존 단순 boolean API 유지 (다른 코드가 쓰고 있을 수 있으니) */
    public boolean verifyCode(String email, String code) {
        return verifyCodeWithReason(email, code) == VerifyResult.SUCCESS;
    }

    // ============ 내부 유틸 ============

    private String generateCode() {
        int num = ThreadLocalRandom.current().nextInt(100000, 1000000); // 6자리
        return String.valueOf(num);
    }

    private boolean isValidEmail(String email) {
        return email != null && email.contains("@") && email.contains(".");
    }

    private void sendMail(String email, String code) throws Exception {
        // 템플릿이 이미 프로젝트에 있을 수도 있으니, 가능하면 재사용
        String html = loadTemplateHtml(code);

        MimeMessage mimeMessage = mailSender.createMimeMessage();
        MimeMessageHelper helper =
                new MimeMessageHelper(mimeMessage, MimeMessageHelper.MULTIPART_MODE_MIXED_RELATED, "UTF-8");

        helper.setTo(email);
        helper.setSubject("\uD83D\uDCF8 네컷모아 이메일 인증 코드");
        helper.setText(html, true);

        mailSender.send(mimeMessage);
    }

    private String loadTemplateHtml(String code) {
        try {
            ClassPathResource resource = new ClassPathResource("templates/email-verification.html");
            String template = Files.readString(resource.getFile().toPath(), StandardCharsets.UTF_8);

            // 템플릿의 {{CODE}} 치환
            return template.replace("{{CODE}}", code);

        } catch (Exception e) {
            // fallback (템플릿 실패 시)
            return """
                    <html><body>
                     <p>네컷모아 이메일 인증</p>
                     <h2>""" + code + """
                     </h2>
                    </body></html>
                    """;

        }
    }

}
