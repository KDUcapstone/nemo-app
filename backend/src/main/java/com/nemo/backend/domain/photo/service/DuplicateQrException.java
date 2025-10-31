package com.nemo.backend.domain.photo.service;

public class DuplicateQrException extends RuntimeException {
    public DuplicateQrException(String message) { super(message); }
}
