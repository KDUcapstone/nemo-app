package com.nemo.backend.domain.photo.service;

import org.springframework.web.multipart.MultipartFile;

public interface PhotoStorage {
    /** 업로드한 파일을 저장하고, 공개 URL로 변환 가능한 '키'를 반환한다. */
    String store(MultipartFile file);
}
