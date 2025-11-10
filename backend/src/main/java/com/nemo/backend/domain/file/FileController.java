// C:\Users\mhy78\IdeaProjects\nemo-app\backend\src\main\java\com\nemo\backend\domain\file\FileController.java
package com.nemo.backend.domain.file;

import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.HandlerMapping;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;

@RestController
@RequiredArgsConstructor
public class FileController {

    private final S3FileService fileService;

    @GetMapping("/files/**")
    public ResponseEntity<ByteArrayResource> getFile(HttpServletRequest request) {
        String path = (String) request.getAttribute(HandlerMapping.PATH_WITHIN_HANDLER_MAPPING_ATTRIBUTE);
        String key = path.substring("/files/".length());

        var obj = fileService.get(key);

        ByteArrayResource body = new ByteArrayResource(obj.bytes());
        String filename = key.substring(key.lastIndexOf('/') + 1);
        String encoded = URLEncoder.encode(filename, StandardCharsets.UTF_8).replace("+", "%20");

        String ct = (obj.contentType() == null || obj.contentType().isBlank())
                ? "application/octet-stream" : obj.contentType();

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(ct)) // ← 정확한 MIME
                .contentLength(obj.contentLength() == null ? obj.bytes().length : obj.contentLength())
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename*=UTF-8''" + encoded)
                .cacheControl(CacheControl.maxAge(Duration.ofDays(30)).cachePublic())
                .body(body);
    }
}
