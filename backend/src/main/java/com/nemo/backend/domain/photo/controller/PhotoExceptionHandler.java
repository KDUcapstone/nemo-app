package com.nemo.backend.domain.photo.controller;

import com.nemo.backend.domain.photo.service.DuplicateQrException;
import com.nemo.backend.domain.photo.service.InvalidQrException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice(assignableTypes = PhotoController.class)
public class PhotoExceptionHandler {
    @ExceptionHandler(InvalidQrException.class)
    public ResponseEntity<Map<String, Object>> handleInvalidQr(InvalidQrException e) {
        return buildResponse(HttpStatus.BAD_REQUEST, e.getMessage());
    }
    @ExceptionHandler(DuplicateQrException.class)
    public ResponseEntity<Map<String, Object>> handleDuplicateQr(DuplicateQrException e) {
        return buildResponse(HttpStatus.CONFLICT, e.getMessage());
    }
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> handleBadRequest(IllegalArgumentException e) {
        return buildResponse(HttpStatus.BAD_REQUEST, e.getMessage());
    }
    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, Object>> handleForbidden(IllegalStateException e) {
        return buildResponse(HttpStatus.FORBIDDEN, e.getMessage());
    }
    private ResponseEntity<Map<String, Object>> buildResponse(HttpStatus status, String message) {
        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now());
        body.put("message", message);
        return ResponseEntity.status(status).body(body);
    }
}