package com.nemo.backend.domain.photo.service;

import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;

/** 다운로드한 파일을 업로드(예: S3)하고 접근 URL을 반환하는 포트 */
public interface PhotoStorage {
    String store(MultipartFile file) throws IOException;
}
