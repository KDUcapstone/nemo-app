// backend/src/main/java/com/nemo/backend/domain/photo/service/ExpiredQrException.java
package com.nemo.backend.domain.photo.service;

public class ExpiredQrException extends RuntimeException {
    public ExpiredQrException(String message) { super(message); }
    public ExpiredQrException(String message, Throwable cause) { super(message, cause); }
}
