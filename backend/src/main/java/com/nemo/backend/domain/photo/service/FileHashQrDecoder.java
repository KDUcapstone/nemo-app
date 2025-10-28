package com.nemo.backend.domain.photo.service;

import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * 외부 라이브러리에 의존하지 않는 QR 디코더 구현.
 * QR 이미지의 바이트 배열을 SHA-256 해시로 변환하여 문자열을 반환합니다.
 * QR에 내포된 URL이나 만료 정보는 읽을 수 없지만, 각 QR 파일을 고유하게 식별할 수 있습니다.
 */
@Service
public class FileHashQrDecoder implements QrDecoder {
    @Override
    public String decode(MultipartFile qrFile) {
        if (qrFile == null || qrFile.isEmpty()) {
            return null;
        }
        try {
            byte[] data = qrFile.getBytes();
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(data);
            return HexFormat.of().formatHex(digest);
        } catch (IOException | NoSuchAlgorithmException e) {
            return null;
        }
    }
}
