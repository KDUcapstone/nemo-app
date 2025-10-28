package com.nemo.backend.domain.photo.service;

/** 만료된 QR 또는 연동 자원이 더 이상 존재하지 않는 경우 */
public class ExpiredQrException extends RuntimeException {
    public ExpiredQrException(String message) { super(message); }
    public ExpiredQrException(String message, Throwable cause) { super(message, cause); }
}
