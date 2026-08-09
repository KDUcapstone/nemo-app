// backend/src/main/java/com/nemo/backend/global/exception/GlobalExceptionHandler.java
package com.nemo.backend.global.exception;

import com.nemo.backend.domain.photo.service.*;
import com.nemo.backend.domain.storage.exception.PhotoLimitExceededException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.HttpMediaTypeNotAcceptableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import jakarta.servlet.http.HttpServletRequest;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final MediaType JSON_UTF8 =
            new MediaType("application", "json", StandardCharsets.UTF_8);

    private Map<String, Object> body(String code, String message) {
        return Map.of(
                "timestamp", Instant.now().toString(),
                "error", code,
                "message", message == null ? "" : message
        );
    }

    // 공용 ApiException
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<Map<String, Object>> handleApi(ApiException ex,
                                                         HttpServletRequest request) {
        ErrorCode code = ex.getErrorCode();
        log.warn("[API-ERROR] {} {} → {}({}) - {}",
                request.getMethod(),
                request.getRequestURI(),
                code.getCode(),
                code.getStatus().value(),
                ex.getMessage());

        return ResponseEntity.status(code.getStatus())
                .contentType(JSON_UTF8)
                .body(body(code.getCode(), ex.getMessage()));
    }

    // ===== 사진/QR 전용 (원인별 상태 분리) =====
    @ExceptionHandler(InvalidQrException.class)
    public ResponseEntity<Map<String, Object>> invalid(InvalidQrException ex,
                                                       HttpServletRequest request) {
        log.warn("[QR-INVALID] {} {} - {}",
                request.getMethod(), request.getRequestURI(), ex.getMessage());

        return ResponseEntity.status(ErrorCode.INVALID_QR.getStatus()).contentType(JSON_UTF8)
                .body(body(ErrorCode.INVALID_QR.getCode(), ex.getMessage()));
    }

    @ExceptionHandler(ExpiredQrException.class)
    public ResponseEntity<Map<String, Object>> expired(ExpiredQrException ex,
                                                       HttpServletRequest request) {
        log.warn("[QR-EXPIRED] {} {} - {}",
                request.getMethod(), request.getRequestURI(), ex.getMessage());

        return ResponseEntity.status(ErrorCode.EXPIRED_QR.getStatus()).contentType(JSON_UTF8)
                .body(body(ErrorCode.EXPIRED_QR.getCode(), ex.getMessage()));
    }

    @ExceptionHandler(DuplicateQrException.class)
    public ResponseEntity<Map<String, Object>> duplicate(DuplicateQrException ex,
                                                         HttpServletRequest request) {
        log.warn("[QR-DUPLICATE] {} {} - {}",
                request.getMethod(), request.getRequestURI(), ex.getMessage());

        return ResponseEntity.status(ErrorCode.DUPLICATE_QR.getStatus()).contentType(JSON_UTF8)
                .body(body(ErrorCode.DUPLICATE_QR.getCode(), ex.getMessage()));
    }

    @ExceptionHandler(NetworkFetchException.class)
    public ResponseEntity<Map<String, Object>> network(NetworkFetchException ex,
                                                       HttpServletRequest request) {
        log.warn("[QR-NETWORK] {} {} - {}",
                request.getMethod(), request.getRequestURI(), ex.getMessage());

        return ResponseEntity.status(ErrorCode.NETWORK_FAILED.getStatus()).contentType(JSON_UTF8)
                .body(body(ErrorCode.NETWORK_FAILED.getCode(), ex.getMessage()));
    }

    @ExceptionHandler(StorageException.class)
    public ResponseEntity<Map<String, Object>> storage(StorageException ex,
                                                       HttpServletRequest request) {
        log.error("[STORAGE-FAILED] {} {} - {}",
                request.getMethod(), request.getRequestURI(), ex.getMessage(), ex);

        return ResponseEntity.status(ErrorCode.STORAGE_FAILED.getStatus()).contentType(JSON_UTF8)
                .body(body(ErrorCode.STORAGE_FAILED.getCode(), ex.getMessage()));
    }

    // ===== 기타 표준화 =====
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> invalidParam(MethodArgumentNotValidException ex,
                                                            HttpServletRequest request) {
        log.warn("[VALIDATION_FAILED] {} {} - {}",
                request.getMethod(), request.getRequestURI(), ex.getMessage());

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).contentType(JSON_UTF8)
                .body(body(ErrorCode.VALIDATION_FAILED.getCode(), "요청 파라미터가 잘못되었습니다."));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> illegal(IllegalArgumentException ex,
                                                       HttpServletRequest request) {
        String msg = ex.getMessage();
        HttpStatus status = (msg != null && (msg.contains("이미 가입된") || msg.contains("중복")))
                ? HttpStatus.CONFLICT : HttpStatus.BAD_REQUEST;
        String code = (status == HttpStatus.CONFLICT)
                ? ErrorCode.CONFLICT.getCode()
                : ErrorCode.INVALID_REQUEST.getCode();

        log.warn("[ILLEGAL_ARGUMENT] {} {} → {}({}) - {}",
                request.getMethod(), request.getRequestURI(), code, status.value(), msg);

        return ResponseEntity.status(status).contentType(JSON_UTF8)
                .body(body(code, msg));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> constraint(DataIntegrityViolationException ex,
                                                          HttpServletRequest request) {
        log.warn("[CONSTRAINT_VIOLATION] {} {} - {}",
                request.getMethod(), request.getRequestURI(), ex.getMostSpecificCause().getMessage());

        return ResponseEntity.status(HttpStatus.CONFLICT).contentType(JSON_UTF8)
                .body(body("CONSTRAINT_VIOLATION", "중복 데이터로 처리할 수 없습니다."));
    }

    @ExceptionHandler(HttpMediaTypeNotAcceptableException.class)
    public ResponseEntity<Map<String, Object>> notAcceptable(HttpMediaTypeNotAcceptableException ex,
                                                             HttpServletRequest request) {
        log.warn("[NOT_ACCEPTABLE] {} {} - {}",
                request.getMethod(), request.getRequestURI(), ex.getMessage());

        return ResponseEntity.status(HttpStatus.NOT_ACCEPTABLE).contentType(JSON_UTF8)
                .body(body("NOT_ACCEPTABLE", "요청/응답의 미디어 타입이 맞지 않습니다."));
    }

    // 🔹 추가: 지원하지 않는 HTTP 메서드 (ex: GET인데 @PostMapping만 있을 때)
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<Map<String, Object>> methodNotSupported(HttpRequestMethodNotSupportedException ex,
                                                                  HttpServletRequest request) {
        log.warn("[METHOD_NOT_ALLOWED] {} {} - supported: {}",
                request.getMethod(),
                request.getRequestURI(),
                ex.getSupportedHttpMethods());

        // ErrorCode에 따로 항목은 없어서, HTTP 405 + 고정 코드 문자열 사용
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED)
                .contentType(JSON_UTF8)
                .body(body("METHOD_NOT_ALLOWED", "지원하지 않는 HTTP 메서드입니다."));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<Map<String, Object>> notFound(NoResourceFoundException ex,
                                                        HttpServletRequest request) {
        log.warn("[NOT_FOUND] {} {}", request.getMethod(), request.getRequestURI());

        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .contentType(JSON_UTF8)
                .body(body(ErrorCode.NOT_FOUND.getCode(), ErrorCode.NOT_FOUND.getMessage()));
    }

    @ExceptionHandler(HttpClientErrorException.TooManyRequests.class)
    public ResponseEntity<Map<String, Object>> tooMany(HttpClientErrorException.TooManyRequests e,
                                                       HttpServletRequest request) {
        log.warn("[EX-429→503] {} {} - {}",
                request.getMethod(), request.getRequestURI(), e.getMessage());

        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).contentType(JSON_UTF8)
                .body(Map.of("code","NAVER_RATE_LIMIT","msg","잠시 후 자동 재시도 중입니다."));
    }

    @ExceptionHandler(HttpClientErrorException.class)
    public ResponseEntity<Map<String, Object>> http4xx(HttpClientErrorException e,
                                                       HttpServletRequest request) {
        log.warn("[EX-4xx] {} {} - status={} msg={}",
                request.getMethod(), request.getRequestURI(), e.getStatusCode(), e.getMessage());

        return ResponseEntity.status(e.getStatusCode()).contentType(JSON_UTF8)
                .body(Map.of("code","REMOTE_4XX","msg","요청이 올바른지 확인해주세요."));
    }

    // ===== 저장 한도 초과 (PHOTO_LIMIT_EXCEEDED) =====
    @ExceptionHandler(PhotoLimitExceededException.class)
    public ResponseEntity<Map<String, Object>> photoLimit(PhotoLimitExceededException ex,
                                                          HttpServletRequest request) {
        log.warn("[PHOTO_LIMIT_EXCEEDED] {} {} - used={}/{} msg={}",
                request.getMethod(), request.getRequestURI(),
                ex.getUsedPhotos(), ex.getMaxPhotos(), ex.getMessage());

        Map<String, Object> base = new HashMap<>(body(
                ErrorCode.PHOTO_LIMIT_EXCEEDED.getCode(),
                ex.getMessage()
        ));
        base.put("maxPhotos", ex.getMaxPhotos());
        base.put("usedPhotos", ex.getUsedPhotos());

        return ResponseEntity
                .status(ErrorCode.PHOTO_LIMIT_EXCEEDED.getStatus())
                .contentType(JSON_UTF8)
                .body(base);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> any(Exception ex,
                                                   HttpServletRequest request) {
        log.error("[UNEXPECTED] {} {} - {}",
                request.getMethod(), request.getRequestURI(), ex.getMessage(), ex);

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).contentType(JSON_UTF8)
                .body(body(ErrorCode.INTERNAL_ERROR.getCode(), "서버 오류가 발생했습니다."));
    }
}
