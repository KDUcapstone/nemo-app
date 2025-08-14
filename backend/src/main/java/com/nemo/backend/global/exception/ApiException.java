package com.nemo.backend.global.exception;

/**
 * Custom runtime exception containing an {@link ErrorCode}.  Thrown by
 * services when an error occurs that should be translated into an HTTP
 * response.
 */
public class ApiException extends RuntimeException {
    private final ErrorCode errorCode;
    public ApiException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }
    public ErrorCode getErrorCode() {
        return errorCode;
    }
}