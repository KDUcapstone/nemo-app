package com.nemo.backend.domain.photo.service;

import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;

public class DuplicateQrException extends ApiException {
    public DuplicateQrException(String message) { super(ErrorCode.DUPLICATE_QR, message); }
}
