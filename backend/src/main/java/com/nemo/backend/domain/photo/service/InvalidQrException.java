// backend/src/main/java/com/nemo/backend/domain/photo/service/InvalidQrException.java
package com.nemo.backend.domain.photo.service;

public class InvalidQrException extends RuntimeException {
    public InvalidQrException(String message) { super(message); }
    public InvalidQrException(String message, Throwable cause) { super(message, cause); }
}
