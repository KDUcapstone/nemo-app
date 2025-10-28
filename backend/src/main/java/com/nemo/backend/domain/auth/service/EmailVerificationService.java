package com.nemo.backend.domain.auth.service;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ThreadLocalRandom;

import lombok.RequiredArgsConstructor;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class EmailVerificationService {

    private final JavaMailSender mailSender;
    private final ConcurrentHashMap<String, String> verificationCodes = new ConcurrentHashMap<>();

    /** 인증코드 발송 */
    public void sendVerificationCode(String email) {
        String code = String.format("%06d",
                ThreadLocalRandom.current().nextInt(0, 1000000));
        verificationCodes.put(email, code);

        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(email);
        message.setSubject("네컷모아 이메일 인증 코드");
        message.setText("앱에 아래 인증 코드를 입력해주세요:\n\n" + code);
        mailSender.send(message);
    }

    /** 인증코드 검증 */
    public boolean verifyCode(String email, String code) {
        String stored = verificationCodes.get(email);
        return stored != null && stored.equals(code);
    }
}
