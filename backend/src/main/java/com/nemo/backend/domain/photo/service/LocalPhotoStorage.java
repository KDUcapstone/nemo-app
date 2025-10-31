package com.nemo.backend.domain.photo.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

@Component
public class LocalPhotoStorage implements PhotoStorage {
    private final Path uploadDir;
    public LocalPhotoStorage(@Value("${photo.upload.dir:uploads}") String uploadDir) {
        this.uploadDir = Paths.get(uploadDir);
        if (!Files.exists(this.uploadDir)) {
            try {
                Files.createDirectories(this.uploadDir);
            } catch (IOException e) {
                throw new RuntimeException("업로드 디렉토리를 생성할 수 없습니다.", e);
            }
        }
    }
    @Override
    public String store(MultipartFile file) throws IOException {
        String originalFilename = file.getOriginalFilename();
        String extension = "";
        if (originalFilename != null && originalFilename.contains(".")) {
            extension = originalFilename.substring(originalFilename.lastIndexOf('.'));
        }
        String filename = UUID.randomUUID().toString() + extension;
        Path target = uploadDir.resolve(filename);
        Files.copy(file.getInputStream(), target);
        return uploadDir.getFileName().toString() + "/" + filename;
    }
}