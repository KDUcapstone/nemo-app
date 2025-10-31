package com.nemo.backend.global.exception;

import com.nemo.backend.domain.photo.service.DuplicateQrException;
import com.nemo.backend.domain.photo.service.ExpiredQrException;
import com.nemo.backend.domain.photo.service.InvalidQrException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

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
}
