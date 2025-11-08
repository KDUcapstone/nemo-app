package com.nemo.backend.domain.photo.service;

import org.springframework.web.multipart.MultipartFile;

public interface PhotoStorage {
    /**
     * 업로드한 파일을 저장하고 외부에서 접근 가능한 **키** 또는 **URL**을 반환한다.
     * (본 구현에선 "키"를 반환하고, 외부 URL 변환은 Service에서 처리)
     */
    String store(MultipartFile file) throws Exception;
}
