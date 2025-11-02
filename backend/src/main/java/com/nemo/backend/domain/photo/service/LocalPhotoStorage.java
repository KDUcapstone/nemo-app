package com.nemo.backend.domain.photo.service;

import org.springframework.beans.factory.annotation.Value;
// @Component  // ← S3만 쓰려면 주석 유지. 로컬 저장을 쓸 때만 활성화
public class LocalPhotoStorage implements PhotoStorage {

    private final java.nio.file.Path uploadDir;

    public LocalPhotoStorage(@Value("${photo.upload.dir:uploads}") String uploadDir) {
        this.uploadDir = java.nio.file.Paths.get(uploadDir);
        if (!java.nio.file.Files.exists(this.uploadDir)) {
            try {
                java.nio.file.Files.createDirectories(this.uploadDir);
            } catch (java.io.IOException e) {
                throw new RuntimeException("업로드 디렉토리를 생성할 수 없습니다.", e);
            }
        }
    }

    @Override
    public String store(org.springframework.web.multipart.MultipartFile file) {
        try {
            String originalFilename = file.getOriginalFilename();
            String extension = "";
            if (originalFilename != null && originalFilename.lastIndexOf('.') >= 0) {
                extension = originalFilename.substring(originalFilename.lastIndexOf('.'));
            }

            String filename = java.util.UUID.randomUUID().toString() + extension;
            java.nio.file.Path target = uploadDir.resolve(filename);

            java.nio.file.Files.copy(file.getInputStream(), target,
                    java.nio.file.StandardCopyOption.REPLACE_EXISTING);

            // 필요 시 절대 URL로 반환하도록 수정 가능 (예: http://localhost:8080/uploads/...)
            return uploadDir.getFileName().toString() + "/" + filename;
        } catch (java.io.IOException e) {
            throw new RuntimeException("로컬 업로드 실패", e);
        }
    }
}
