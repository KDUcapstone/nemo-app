package com.nemo.backend.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.util.AntPathMatcher;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;

import java.io.OutputStream;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;

@RestController
public class FileProxyController {

    private final S3Client s3;
    private final String bucket;

    public FileProxyController(S3Client s3, @Value("${app.s3.bucket}") String bucket) {
        this.s3 = s3;
        this.bucket = bucket;
    }

    @GetMapping("/files/**")
    public void get(HttpServletRequest req, HttpServletResponse res) throws Exception {
        // /files/ 이하 전체 키 추출
        String path = req.getRequestURI();             // /files/albums/2025-11-02/uuid-name.png
        String key = new AntPathMatcher().extractPathWithinPattern("/files/**", path);
        key = URLDecoder.decode(key, StandardCharsets.UTF_8);

        var gor = GetObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .build();

        // 간단히 content-type 추정 (없으면 octet-stream)
        String ctype = MediaType.APPLICATION_OCTET_STREAM_VALUE;
        String lower = key.toLowerCase();
        if (lower.endsWith(".png"))  ctype = MediaType.IMAGE_PNG_VALUE;
        else if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) ctype = MediaType.IMAGE_JPEG_VALUE;
        else if (lower.endsWith(".gif")) ctype = MediaType.IMAGE_GIF_VALUE;
        else if (lower.endsWith(".webp")) ctype = "image/webp";
        else if (lower.endsWith(".mp4")) ctype = "video/mp4";

        res.setHeader(HttpHeaders.CACHE_CONTROL, "public, max-age=31536000, immutable");
        res.setContentType(ctype);

        try (var s3is = s3.getObject(gor); OutputStream os = res.getOutputStream()) {
            s3is.transferTo(os);
        }
    }
}
