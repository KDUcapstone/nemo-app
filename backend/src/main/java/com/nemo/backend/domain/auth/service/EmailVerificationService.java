package com.nemo.backend.domain.auth.service;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ThreadLocalRandom;

import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ClassPathResource;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class EmailVerificationService {

    private final JavaMailSender mailSender;
    private final ConcurrentHashMap<String, String> verificationCodes = new ConcurrentHashMap<>();

    /** 인증코드 발송 (HTML 버전) */
    public void sendVerificationCode(String email) {
        String code = String.format("%06d",
                ThreadLocalRandom.current().nextInt(0, 1000000));

        verificationCodes.put(email, code);

        try {
            // 📄 템플릿 파일 로드
            var resource = new ClassPathResource("templates/email-verification.html");
            String htmlTemplate = Files.readString(resource.getFile().toPath(), StandardCharsets.UTF_8);

            // {{code}} 치환
            String htmlContent = htmlTemplate.replace("{{code}}", code);

            // ✉️ 메일 생성 및 전송
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            helper.setTo(email);
            helper.setFrom("hwkimv@gmail.com");
            helper.setSubject("📸 네컷모아 이메일 인증 코드");
            helper.setText(htmlContent, true);

            mailSender.send(message);

        } catch (Exception e) {
            throw new RuntimeException("메일 전송 실패: " + e.getMessage(), e);
        }
    }

    /** 인증코드 검증 */
    public boolean verifyCode(String email, String code) {
        String stored = verificationCodes.get(email);
        return stored != null && stored.equals(code);
    }
}
