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
    UPSTREAM_FAILED(HttpStatus.BAD_GATEWAY,  "UPSTREAM_FAILED", "원격 자산 추출 실패했습니다.");



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
