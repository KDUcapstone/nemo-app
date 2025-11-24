package com.nemo.backend.global.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

/** 공용 에러 코드 정의 */
@Getter
public enum ErrorCode {
    // 인증/사용자
    DUPLICATE_EMAIL(HttpStatus.CONFLICT, "DUPLICATE_EMAIL", "이미 사용 중인 이메일입니다."),
    INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "이메일 또는 비밀번호를 확인해주세요."),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "로그인이 필요합니다."),
    USER_ALREADY_DELETED(HttpStatus.GONE, "USER_ALREADY_DELETED", "이미 탈퇴 처리된 사용자입니다."),

    // 🔹 추가: 토큰/비밀번호 관련
    INVALID_REFRESH_TOKEN(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "리프레시 토큰이 유효하지 않거나 만료되었습니다."),
    INVALID_PASSWORD(HttpStatus.FORBIDDEN, "INVALID_PASSWORD", "입력하신 비밀번호가 올바르지 않습니다."),
    INVALID_CURRENT_PASSWORD(HttpStatus.FORBIDDEN, "INVALID_CURRENT_PASSWORD", "현재 비밀번호가 일치하지 않습니다."),
    PASSWORD_CONFIRM_MISMATCH(HttpStatus.BAD_REQUEST, "PASSWORD_CONFIRM_MISMATCH", "새 비밀번호와 확인 값이 일치하지 않습니다."),
    PASSWORD_POLICY_VIOLATION(HttpStatus.BAD_REQUEST, "PASSWORD_POLICY_VIOLATION", "비밀번호 정책을 만족하지 않습니다."),

    // 공통
    INVALID_REQUEST(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "잘못된 요청입니다."),
    FORBIDDEN(HttpStatus.FORBIDDEN, "FORBIDDEN", "권한이 없습니다."),
    NOT_FOUND(HttpStatus.NOT_FOUND, "NOT_FOUND", "리소스를 찾을 수 없습니다."),
    CONFLICT(HttpStatus.CONFLICT, "CONFLICT", "요청이 충돌했습니다."),
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "서버 오류가 발생했습니다."),

    // 사진/QR 세부 코드 (추가)
    INVALID_QR(HttpStatus.BAD_REQUEST, "INVALID_QR", "지원하지 않는 QR입니다."),
    EXPIRED_QR(HttpStatus.NOT_FOUND, "EXPIRED_QR", "만료되었거나 접근 불가한 QR입니다."),
    DUPLICATE_QR(HttpStatus.CONFLICT, "DUPLICATE_QR", "이미 업로드된 QR입니다."),
    STORAGE_FAILED(HttpStatus.BAD_GATEWAY, "STORAGE_FAILED", "파일 저장에 실패했습니다."),
    NETWORK_FAILED(HttpStatus.BAD_GATEWAY, "NETWORK_FAILED", "원본 사진을 가져오지 못했습니다."),
    VALIDATION_FAILED(HttpStatus.BAD_REQUEST, "VALIDATION_FAILED", "요청 파라미터가 잘못되었습니다."),
    INVALID_ARGUMENT(HttpStatus.BAD_REQUEST, "INVALID_ARGUMENT", "잘못된 입력입니다."),
    UPSTREAM_FAILED(HttpStatus.BAD_GATEWAY,  "UPSTREAM_FAILED", "원격 자산 추출 실패했습니다."),

    // 캘린더 타임라인 코드
    INVALID_QUERY(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "year와 month 파라미터는 필수입니다.");

    private final HttpStatus status;
    private final String code;
    private final String message;

    ErrorCode(HttpStatus status, String code, String message) {
        this.status = status;
        this.code = code;
        this.message = message;
    }

    public int getHttpStatus() { return status.value(); }
}