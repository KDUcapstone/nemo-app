package com.nemo.backend.domain.photo.service;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

/**
 * 테스트 환경에서 사용되는 스텁 QR 디코더.
 * QR 이미지에서 아무 문자열도 읽지 않고 항상 null을 반환합니다.
 */
@Profile("test")
@Service
public class StubQrDecoder implements QrDecoder {
    @Override
    public String decode(MultipartFile qrFile) {
        return null; // 테스트에서는 QR 해석을 하지 않음
    }
}
