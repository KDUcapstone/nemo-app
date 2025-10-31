package com.nemo.backend.domain.auth.controller;

import java.util.Collections;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import com.nemo.backend.domain.auth.service.EmailVerificationService;

@RestController
@RequestMapping("/api/auth/email/verification")
@RequiredArgsConstructor
public class EmailVerificationController {

    private final EmailVerificationService emailVerificationService;

    @PostMapping("/send")
    public ResponseEntity<?> sendVerification(@RequestBody Map<String, String> req) {
        String email = req.get("email");
        emailVerificationService.sendVerificationCode(email);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/confirm")
    public ResponseEntity<?> confirm(@RequestBody Map<String, String> req) {
        String email = req.get("email");
        String code  = req.get("code");
        boolean ok   = emailVerificationService.verifyCode(email, code);
        if (ok) {
            return ResponseEntity.ok().build();
        } else {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Collections.singletonMap("message", "인증 코드가 올바르지 않습니다."));
        }
    }
}
