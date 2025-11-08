// backend/src/main/java/com/nemo/backend/domain/photo/service/DuplicateQrException.java
package com.nemo.backend.domain.photo.service;

public class DuplicateQrException extends RuntimeException {
    public DuplicateQrException(String message) { super(message); }
    public DuplicateQrException(String message, Throwable cause) { super(message, cause); }
}
