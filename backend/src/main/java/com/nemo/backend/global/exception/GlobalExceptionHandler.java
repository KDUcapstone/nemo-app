// backend/src/main/java/com/nemo/backend/global/exception/GlobalExceptionHandler.java
package com.nemo.backend.global.exception;

import com.nemo.backend.domain.photo.service.DuplicateQrException;
import com.nemo.backend.domain.photo.service.ExpiredQrException;
import com.nemo.backend.domain.photo.service.InvalidQrException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.HttpMediaTypeNotAcceptableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    // 0) 통일된 바디 생성기 (항상 JSON)
    private Map<String, Object> body(String code, String message) {
        return Map.of(
                "timestamp", Instant.now().toString(),
                "error", code,
                "message", message == null ? "" : message
        );
    }

    // 1) 프로젝트 공용 예외 -> ErrorCode 기반 상태/메시지 반환
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<Map<String, Object>> handleApi(ApiException ex) {
        ErrorCode code = ex.getErrorCode();
        return ResponseEntity
                .status(code.getStatus())
                .body(body(code.getCode(), code.getMessage()));
    }

    // 2) 도메인 예외 - QR
    @ExceptionHandler(InvalidQrException.class)
    public ResponseEntity<Map<String, Object>> handleInvalid(InvalidQrException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(body("INVALID_QR", ex.getMessage()));
    }

    @ExceptionHandler(ExpiredQrException.class)
    public ResponseEntity<Map<String, Object>> handleExpired(ExpiredQrException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(body("EXPIRED_QR", ex.getMessage()));
    }

    @ExceptionHandler(DuplicateQrException.class)
    public ResponseEntity<Map<String, Object>> handleDuplicate(DuplicateQrException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(body("DUPLICATE_QR", ex.getMessage()));
    }

    // 3) 일반 비즈니스 예외(중복 이메일 등) -> 409/400로 표준화
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> handleIllegal(IllegalArgumentException ex) {
        String msg = ex.getMessage();
        HttpStatus status =
                (msg != null && (msg.contains("이미 가입된") || msg.contains("중복")))
                        ? HttpStatus.CONFLICT
                        : HttpStatus.BAD_REQUEST;
        String code =
                (status == HttpStatus.CONFLICT) ? "CONFLICT" : "BAD_REQUEST";
        return ResponseEntity.status(status).body(body(code, msg));
    }

    // 4) DB 유니크/제약 충돌 -> 409
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> handleConstraint(DataIntegrityViolationException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(body("CONSTRAINT_VIOLATION", "중복 데이터로 처리할 수 없습니다."));
    }

    // 5) 406 방지: Jackson이 JSON 못 만들 때/클라 Accept 불일치
    @ExceptionHandler(HttpMediaTypeNotAcceptableException.class)
    public ResponseEntity<Map<String, Object>> handleNotAcceptable(HttpMediaTypeNotAcceptableException ex) {
        return ResponseEntity.status(HttpStatus.NOT_ACCEPTABLE)
                .body(body("NOT_ACCEPTABLE", "요청/응답의 미디어 타입이 맞지 않습니다."));
    }

    // 6) 마지막 안전망 -> 500
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleAny(Exception ex) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(body("INTERNAL_ERROR", "서버 오류가 발생했습니다."));
    }
}
