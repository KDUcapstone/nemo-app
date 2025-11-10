package com.nemo.backend.domain.photo.service;

import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;

public class ExpiredQrException extends ApiException {
    public ExpiredQrException(String message) { super(ErrorCode.EXPIRED_QR, message); }
    public ExpiredQrException(String message, Throwable cause) { super(ErrorCode.EXPIRED_QR, message, cause); }
}
