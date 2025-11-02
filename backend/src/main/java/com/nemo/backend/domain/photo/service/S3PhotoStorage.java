package com.nemo.backend.domain.photo.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import java.io.IOException;
import java.net.URI;
import java.time.LocalDate;
import java.util.UUID;

@Primary
@Component
public class S3PhotoStorage implements PhotoStorage {

    private final S3Client s3Client;
    private final String bucket;

    public S3PhotoStorage(
            @Value("${app.s3.endpoint}") String endpoint,
            @Value("${app.s3.region}") String region,
            @Value("${app.s3.accessKey:test}") String accessKey,
            @Value("${app.s3.secretKey:test}") String secretKey,
            @Value("${app.s3.bucket}") String bucket
    ) {
        this.bucket = bucket;
        this.s3Client = S3Client.builder()
                .region(Region.of(region))
                .endpointOverride(URI.create(endpoint))
                .credentialsProvider(
                        StaticCredentialsProvider.create(AwsBasicCredentials.create(accessKey, secretKey))
                )
                .forcePathStyle(true)
                .build();
    }

    @Override
    public String store(MultipartFile file) {
        try {
            String key = String.format("albums/%s/%s-%s",
                    LocalDate.now(), UUID.randomUUID(), file.getOriginalFilename());

            PutObjectRequest req = PutObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .contentType(file.getContentType())
                    .build();

            s3Client.putObject(req, RequestBody.fromBytes(file.getBytes()));
            return String.format("http://localhost:4566/%s/%s", bucket, key);
        } catch (Exception e) {                          // IOException, S3Exception 등
            throw new RuntimeException("S3 업로드 실패", e); // 런타임 예외로 변환
        }
    }
}
