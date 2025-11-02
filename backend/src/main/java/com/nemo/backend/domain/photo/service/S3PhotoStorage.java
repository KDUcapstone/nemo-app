package com.nemo.backend.domain.photo.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.time.LocalDate;
import java.util.UUID;

@Primary
@Component
public class S3PhotoStorage implements PhotoStorage {

    private final S3Client s3Client;
    private final String bucket;

    public S3PhotoStorage(S3Client s3Client,
                          @Value("${app.s3.bucket}") String bucket) {
        this.s3Client = s3Client;
        this.bucket = bucket;
    }

    /** S3에 업로드하고 "키"만 반환 (예: albums/2025-11-02/uuid-name.png) */
    @Override
    public String store(MultipartFile file) {
        try {
            String today = LocalDate.now().toString();
            String original = (file.getOriginalFilename() == null) ? "file" : file.getOriginalFilename();
            String key = String.format("albums/%s/%s-%s", today, UUID.randomUUID(), original);

            PutObjectRequest req = PutObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .contentType(file.getContentType())
                    .build();

            s3Client.putObject(req, RequestBody.fromBytes(file.getBytes()));
            return key; // URL 아님! 키만 반환
        } catch (Exception e) {
            throw new RuntimeException("S3 업로드 실패", e);
        }
    }
}
