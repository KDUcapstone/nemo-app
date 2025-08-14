package com.nemo.backend.global.exception;

import org.springframework.http.HttpStatus;

/**
 * Enumeration of error codes with corresponding HTTP status and messages.
 */
public enum ErrorCode {
    DUPLICATE_EMAIL(HttpStatus.CONFLICT, "DUPLICATE_EMAIL", "이미 사용 중인 이메일입니다."),
    INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "이메일 또는 비밀번호를 확인해주세요."),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "로그인이 필요합니다."),
    USER_ALREADY_DELETED(HttpStatus.GONE, "USER_ALREADY_DELETED", "이미 탈퇴 처리된 사용자입니다.");
    private final HttpStatus status;
    private final String code;
    private final String message;
    ErrorCode(HttpStatus status, String code, String message) {
        this.status = status;
        this.code = code;
        this.message = message;
    }
    public HttpStatus getStatus() {
        return status;
    }
    public String getCode() {
        return code;
    }
    public String getMessage() {
        return message;
    }
}