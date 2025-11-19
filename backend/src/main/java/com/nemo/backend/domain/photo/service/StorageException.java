package com.nemo.backend.domain.photo.service;

import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;

public class StorageException extends ApiException {
    public StorageException(String message, Throwable cause) { super(ErrorCode.STORAGE_FAILED, message, cause); }
}
