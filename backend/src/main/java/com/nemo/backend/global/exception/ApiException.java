package com.nemo.backend.global.exception;

/**
 * Custom runtime exception containing an {@link ErrorCode}.
 * Services throw this to be translated into an HTTP response.
 */
public class ApiException extends RuntimeException {
    private final ErrorCode errorCode;

    /** 기본 메시지는 ErrorCode의 message 사용 */
    public ApiException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    /** 필요 시 커스텀 메시지로 대체 */
    public ApiException(ErrorCode errorCode, String overrideMessage) {
        super(overrideMessage);
        this.errorCode = errorCode;
    }

    public ErrorCode getErrorCode() { return errorCode; }
}
