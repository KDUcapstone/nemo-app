package com.nemo.backend.domain.photo.service;

import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.exception.SdkClientException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

import java.time.LocalDate;
import java.util.UUID;

@Primary
@Component
public class S3PhotoStorage implements PhotoStorage {

    private final S3Client s3Client;
    private final String bucket;
    private final boolean createBucketIfMissing;

    public S3PhotoStorage(
            S3Client s3Client,
            @Value("${app.s3.bucket}") String bucket,
            @Value("${app.s3.createBucketIfMissing:false}") boolean createBucketIfMissing
    ) {
        this.s3Client = s3Client;
        this.bucket = bucket;
        this.createBucketIfMissing = createBucketIfMissing;
        ensureBucket(); // 시작 시 1회 체크
    }

    private void ensureBucket() {
        try {
            s3Client.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
        } catch (S3Exception e) {
            // 버킷이 없거나 권한이 없는 경우 모두 여기로 옴
            if (!createBucketIfMissing) return;
            try {
                s3Client.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
            } catch (S3Exception ce) {
                throw new ApiException(ErrorCode.STORAGE_FAILED,
                        "S3 버킷 생성 실패: " + ce.awsErrorDetails().errorMessage(), ce);
            }
        } catch (SdkClientException e) {
            // 엔드포인트/네트워크/인증 등 클라이언트 레벨 문제
            throw new ApiException(ErrorCode.STORAGE_FAILED, "S3 연결 실패: " + e.getMessage(), e);
        }
    }

    @Override
    public String store(MultipartFile file) throws Exception {
        String today = LocalDate.now().toString();
        String original = (file.getOriginalFilename() == null) ? "file" : file.getOriginalFilename();
        String key = String.format("albums/%s/%s-%s", today, UUID.randomUUID(), original);

        try {
            PutObjectRequest req = PutObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .contentType(file.getContentType())
                    .build();

            s3Client.putObject(req, RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
            return key;

        } catch (S3Exception e) {
            // AWS 가 반납하는 구체 메시지 포함
            throw new StorageException("S3 업로드 실패: " + e.awsErrorDetails().errorMessage(), e);

        } catch (SdkClientException e) {
            // endpoint/인증/네트워크
            throw new StorageException("S3 클라이언트 오류: " + e.getMessage(), e);

        } catch (Exception e) {
            // 기타 IO 등
            throw new StorageException("파일 저장 실패", e);
        }
    }
}
