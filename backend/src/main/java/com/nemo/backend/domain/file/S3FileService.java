// C:\Users\mhy78\IdeaProjects\nemo-app\backend\src\main\java\com\nemo\backend\domain\file\S3FileService.java
package com.nemo.backend.domain.file;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.sync.ResponseTransformer;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;

@Service
@RequiredArgsConstructor
public class S3FileService {

    public record FileObject(byte[] bytes, String contentType, Long contentLength) {}

    private final S3Client s3Client;

    @Value("${app.s3.bucket}")
    private String bucket;

    public FileObject get(String key) {
        // 앞에 슬래시 들어오면 제거
        String normalizedKey = key.startsWith("/") ? key.substring(1) : key;

        try {
            var req = GetObjectRequest.builder()
                    .bucket(bucket)
                    .key(normalizedKey)
                    .build();

            ResponseBytes<?> bytes = s3Client.getObject(req, ResponseTransformer.toBytes());

            // S3에 content-type이 없으면 확장자로 추정
            String ct = null;
            if (bytes.response() != null) {
                try {
                    var resp = (software.amazon.awssdk.services.s3.model.GetObjectResponse) bytes.response();
                    ct = resp.contentType();
                } catch (ClassCastException ignore) {}
            }
            if (ct == null || ct.isBlank() || "application/octet-stream".equalsIgnoreCase(ct)) {
                ct = guessContentType(normalizedKey); // ← 확장자 기반 추정
            }

            Long len = null;
            if (bytes.response() != null) {
                try {
                    var resp = (software.amazon.awssdk.services.s3.model.GetObjectResponse) bytes.response();
                    len = resp.contentLength();
                } catch (ClassCastException ignore) {}
            }
            if (len == null) len = (long) bytes.asByteArray().length;

            return new FileObject(bytes.asByteArray(), ct, len);

        } catch (NoSuchKeyException e) {
            throw new FileNotFoundException("S3 object not found: " + key);
        }
    }

    private String guessContentType(String key) {
        String k = key.toLowerCase();
        if (k.endsWith(".jpg") || k.endsWith(".jpeg")) return "image/jpeg";
        if (k.endsWith(".png"))  return "image/png";
        if (k.endsWith(".gif"))  return "image/gif";
        if (k.endsWith(".webp")) return "image/webp";
        if (k.endsWith(".bmp"))  return "image/bmp";
        if (k.endsWith(".svg"))  return "image/svg+xml";
        if (k.endsWith(".mp4"))  return "video/mp4";
        if (k.endsWith(".webm")) return "video/webm";
        if (k.endsWith(".mov"))  return "video/quicktime";
        return "application/octet-stream";
    }

    public static class FileNotFoundException extends RuntimeException {
        public FileNotFoundException(String msg) { super(msg); }
    }
}
