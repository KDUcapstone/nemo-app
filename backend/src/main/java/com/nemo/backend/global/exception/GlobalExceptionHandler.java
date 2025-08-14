package com.nemo.backend.global.exception;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

/**
 * Handles API exceptions thrown by controllers and services, converting them
 * into structured JSON responses.
 */
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
}
