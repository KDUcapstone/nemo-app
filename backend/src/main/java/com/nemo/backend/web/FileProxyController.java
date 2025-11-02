package com.nemo.backend.web;

import jakarta.servlet.http.HttpServletRequest;                // ✅ jakarta 사용
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.core.sync.ResponseTransformer;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

@RestController
@RequiredArgsConstructor
public class FileProxyController {

    private final S3Client s3Client;

    @Value("${app.s3.bucket}")
    private String bucket;

    /**
     * /files/ 하위의 모든 경로를 프록시 (Spring 6의 PathPattern에서 {**var}는 에러 → /** 로 처리)
     */
    @GetMapping("/files/**")
    public ResponseEntity<byte[]> getFile(HttpServletRequest request) {
        // 요청 URI에서 /files/ 이후를 키로 사용
        final String prefix = "/files/";
        final String fullPath = request.getRequestURI();              // 예) /files/albums/2025-11-02/uuid-name.png
        final String key = fullPath.substring(prefix.length());       // 예) albums/2025-11-02/uuid-name.png

        try {
            var req = GetObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .build();

            ResponseBytes<?> bytes = s3Client.getObject(req, ResponseTransformer.toBytes());

            // 간단 MIME 추정 (png/jpg/webp/mp4 등만 커버)
            MediaType contentType = guessMediaType(key);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(contentType);
            headers.setContentLength(bytes.asByteArray().length);
            headers.set(HttpHeaders.CONTENT_DISPOSITION,
                    contentDispositionInline(key));

            return new ResponseEntity<>(bytes.asByteArray(), headers, HttpStatus.OK);

        } catch (SdkException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    private MediaType guessMediaType(String key) {
        String k = key.toLowerCase();
        if (k.endsWith(".png"))  return MediaType.IMAGE_PNG;
        if (k.endsWith(".jpg") || k.endsWith(".jpeg")) return MediaType.IMAGE_JPEG;
        if (k.endsWith(".gif"))  return MediaType.IMAGE_GIF;
        if (k.endsWith(".webp")) return MediaType.valueOf("image/webp");
        if (k.endsWith(".mp4"))  return MediaType.valueOf("video/mp4");
        if (k.endsWith(".webm")) return MediaType.valueOf("video/webm");
        if (k.endsWith(".mov"))  return MediaType.valueOf("video/quicktime");
        return MediaType.APPLICATION_OCTET_STREAM;
    }

    private String contentDispositionInline(String key) {
        String fname = key.substring(key.lastIndexOf('/') + 1);
        String encoded = URLEncoder.encode(fname, StandardCharsets.UTF_8).replace("+", "%20");
        return "inline; filename=\"" + fname + "\"; filename*=UTF-8''" + encoded;
    }
}
