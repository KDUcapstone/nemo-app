package com.nemo.backend.domain.photo.service;

import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;

public class InvalidQrException extends ApiException {
    public InvalidQrException(String message) { super(ErrorCode.INVALID_QR, message); }
    public InvalidQrException(String message, Throwable cause) { super(ErrorCode.INVALID_QR, message, cause); }
}
