package com.nemo.backend.domain.photo.service;

import org.springframework.web.multipart.MultipartFile;

public interface PhotoStorage {
    /** 업로드한 파일을 저장하고 외부에서 접근 가능한 키 또는 URL을 반환 */
    String store(MultipartFile file) throws Exception;
}
