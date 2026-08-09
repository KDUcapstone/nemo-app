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

    // email → CodeInfo
    private final Map<String, CodeInfo> verificationCodes = new ConcurrentHashMap<>();

    // 설정값들
    private static final Duration CODE_TTL = Duration.ofMinutes(5);        // 유효 5분
    private static final int MAX_ATTEMPTS = 5;                             // 5회 틀리면 제거
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);// 60초 재전송 쿨다운

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

    /** ---------------------------------------------
     *  📧 인증 코드 발송
     *  ---------------------------------------------*/
    public void sendVerificationCode(String email) {
        if (!isValidEmail(email)) {
            throw new ApiException(ErrorCode.INVALID_EMAIL_FORMAT);
        }

        LocalDateTime now = LocalDateTime.now();
        CodeInfo existing = verificationCodes.get(email);

        // 🔥 재전송 쿨다운 체크
        if (existing != null && existing.lastSentAt != null) {
            if (Duration.between(existing.lastSentAt, now).compareTo(RESEND_COOLDOWN) < 0) {
                throw new ApiException(ErrorCode.RATE_LIMITED);
            }
        }

        // 6자리 코드 생성
        String code = generateCode();

        // Map 업데이트
        CodeInfo info = new CodeInfo(code, now.plus(CODE_TTL), now);
        verificationCodes.put(email, info);

        try {
            sendMail(email, code);
        } catch (Exception e) {
            throw new ApiException(ErrorCode.MAIL_SEND_FAILED, "인증코드 메일을 보내지 못했습니다.");
        }
    }

    /** ---------------------------------------------
     *  🔍 코드 검증 (사유 포함)
     *  ---------------------------------------------*/
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

        verificationCodes.remove(email);
        return VerifyResult.SUCCESS;
    }

    /** 기존 boolean API 유지 */
    public boolean verifyCode(String email, String code) {
        return verifyCodeWithReason(email, code) == VerifyResult.SUCCESS;
    }

    // ==================================================
    // 내부 유틸
    // ==================================================

    private String generateCode() {
        return String.format("%06d", ThreadLocalRandom.current().nextInt(0, 1_000_000));
    }

    private boolean isValidEmail(String email) {
        return email != null && email.contains("@") && email.contains(".");
    }

    /** ---------------------------------------------
     *  ✉️ 이메일 템플릿 로딩 + 발송
     *  ---------------------------------------------*/
    private void sendMail(String email, String code) throws Exception {
        String html = loadTemplateHtml(code);

        MimeMessage mimeMessage = mailSender.createMimeMessage();
        MimeMessageHelper helper =
                new MimeMessageHelper(mimeMessage, true, "UTF-8");

        helper.setTo(email);
        helper.setSubject("📸 네컷모아 이메일 인증 코드");
        helper.setText(html, true);

        mailSender.send(mimeMessage);
    }

    private String loadTemplateHtml(String code) {
        try {
            ClassPathResource resource = new ClassPathResource("templates/email-verification.html");

            // ✅ JAR / 컨테이너 / 로컬 전부에서 안전하게 동작
            try (var is = resource.getInputStream()) {
                String template = new String(is.readAllBytes(), StandardCharsets.UTF_8);

                return template
                        .replace("{{code}}", code)
                        .replace("{{CODE}}", code);
            }

        } catch (Exception e) {
            return """
                    <html><body style='font-family:sans-serif;'>
                        <h2>네컷모아 이메일 인증</h2>
                        <p>아래 인증코드를 입력해주세요.</p>
                        <div style='font-size:32px; font-weight:bold; margin-top:10px;'>"""
                    + code +
                    "</div></body></html>";
        }
    }
}
