package com.nemo.backend.global.exception;

/** ErrorCode를 포함하는 런타임 예외 */
public class ApiException extends RuntimeException {
    private final ErrorCode errorCode;

    public ApiException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    public ApiException(ErrorCode errorCode, String overrideMessage) {
        super(overrideMessage);
        this.errorCode = errorCode;
    }

    public ApiException(ErrorCode errorCode, String overrideMessage, Throwable cause) {
        super(overrideMessage, cause);
        this.errorCode = errorCode;
    }

    public ErrorCode getErrorCode() { return errorCode; }
}
