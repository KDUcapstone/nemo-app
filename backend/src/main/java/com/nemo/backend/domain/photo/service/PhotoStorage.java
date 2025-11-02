package com.nemo.backend.domain.photo.service;

import org.springframework.web.multipart.MultipartFile;

public interface PhotoStorage {
    /** 업로드한 파일을 저장하고 외부 접근 가능한 URL을 반환한다. */
    String store(MultipartFile file);  // ← throws Exception 제거
}
