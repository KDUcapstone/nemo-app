// com.nemo.backend.domain.file.FileController
package com.nemo.backend.domain.file;

import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.HandlerMapping;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;

@RestController
@RequiredArgsConstructor
@RequestMapping(value = "/files", produces = MediaType.APPLICATION_OCTET_STREAM_VALUE)
public class FileController {

    private final S3FileService fileService;

    @GetMapping("/files/**")
    public ResponseEntity<ByteArrayResource> getFile(HttpServletRequest request) {
        String path = (String) request.getAttribute(HandlerMapping.PATH_WITHIN_HANDLER_MAPPING_ATTRIBUTE);
        String key = path.substring("/files/".length());

        var obj = fileService.get(key);

        // S3FileService가 이미 contentType을 계산해서 넘겨줌
        String ct = (obj.contentType() == null || obj.contentType().isBlank())
                ? "application/octet-stream"
                : obj.contentType();

        byte[] bytes = obj.bytes();

        // JPEG이면 sRGB로 정규화(선택: ImageTranscoder 적용 중이면 유지)
        if (ImageTranscoder.looksLikeJpeg(key) || ImageTranscoder.looksLikeJpeg(ct)) {
            bytes = ImageTranscoder.normalizeJpegToSRGB(bytes);
            ct = "image/jpeg";
        }

        ByteArrayResource body = new ByteArrayResource(bytes);
        String filename = key.substring(key.lastIndexOf('/') + 1);
        String encoded = URLEncoder.encode(filename, StandardCharsets.UTF_8).replace("+", "%20");

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(ct))
                .contentLength(bytes.length)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename*=UTF-8''" + encoded)
                .cacheControl(CacheControl.maxAge(Duration.ofDays(30)).cachePublic())
                .body(body);
    }
}
