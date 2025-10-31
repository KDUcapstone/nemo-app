package com.nemo.backend.domain.photo.service;

import org.springframework.web.multipart.MultipartFile;

/** QR 이미지 파일을 받아 페이로드(대개 URL)를 추출하는 포트 */
public interface QrDecoder {
    String decode(MultipartFile qrFile);
}
