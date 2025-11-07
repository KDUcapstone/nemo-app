package com.nemo.backend.global.exception;

import com.nemo.backend.domain.photo.service.DuplicateQrException;
import com.nemo.backend.domain.photo.service.ExpiredQrException;
import com.nemo.backend.domain.photo.service.InvalidQrException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.client.HttpClientErrorException;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<Map<String, Object>> handleApiException(ApiException ex) {
        ErrorCode code = ex.getErrorCode();
        Map<String, Object> body = new HashMap<>();
        body.put("error", code.getCode());
        body.put("message", code.getMessage());
        return ResponseEntity.status(code.getStatus()).body(body);
    }

    // 잘못된 QR → 400
    @ExceptionHandler(InvalidQrException.class)
    public ResponseEntity<Map<String, Object>> handleInvalid(InvalidQrException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of(
                "timestamp", Instant.now().toString(),
                "error", "INVALID_QR",
                "message", ex.getMessage()
        ));
    }

    // 만료/사라진 QR → 404
    @ExceptionHandler(ExpiredQrException.class)
    public ResponseEntity<Map<String, Object>> handleExpired(ExpiredQrException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                "timestamp", Instant.now().toString(),
                "error", "EXPIRED_QR",
                "message", ex.getMessage()
        ));
    }

    // 동일 QR 해시 중복 → 409
    @ExceptionHandler(DuplicateQrException.class)
    public ResponseEntity<Map<String, Object>> handleDuplicate(DuplicateQrException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of(
                "timestamp", Instant.now().toString(),
                "error", "DUPLICATE_QR",
                "message", ex.getMessage()
        ));
    }

    // DB 유니크 제약 충돌도 409로 통일
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> handleConstraint(DataIntegrityViolationException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of(
                "timestamp", Instant.now().toString(),
                "error", "CONFLICT",
                "message", "중복 데이터로 처리할 수 없습니다."
        ));
    }

    // 네이버가 429(Too Many Requests) 보낸 경우 → 503으로 변환
    @ExceptionHandler(HttpClientErrorException.TooManyRequests.class)
    public ResponseEntity<Map<String, Object>> handle429(HttpClientErrorException.TooManyRequests e) {
        log.warn("[EX-429→503] {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(Map.of(
                        "code",  "NAVER_RATE_LIMIT",
                        "msg",   "잠시 후 자동 재시도 중입니다.",
                        "detail", cut(e.getResponseBodyAsString(), 300)
                ));
    }

    // 나머지 4xx는 그대로 전파하거나, 필요 시 400/404로 변환
    @ExceptionHandler(HttpClientErrorException.class)
    public ResponseEntity<Map<String, Object>> handle4xx(HttpClientErrorException e) {
        log.warn("[EX-4xx] {}", e.getMessage());
        return ResponseEntity.status(e.getStatusCode())
                .body(Map.of(
                        "code",  "NAVER_4XX",
                        "msg",   "요청이 올바른지 확인해주세요.",
                        "detail", cut(e.getResponseBodyAsString(), 300)
                ));
    }

    private String cut(String s, int n) {
        if (s == null) return "";
        return s.length() <= n ? s : s.substring(0, n);
    }

}
