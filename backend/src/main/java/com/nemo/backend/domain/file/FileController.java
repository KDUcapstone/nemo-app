package com.nemo.backend.domain.file;

import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.HandlerMapping;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;

@RestController
@RequiredArgsConstructor
@RequestMapping("/files") // 클래스 레벨 고정
public class FileController {

    private final S3FileService fileService;

    @GetMapping("/**") // 단일 매핑
    public ResponseEntity<?> getFile(HttpServletRequest request) {
        String path = (String) request.getAttribute(HandlerMapping.PATH_WITHIN_HANDLER_MAPPING_ATTRIBUTE);
        String key = path.startsWith("/files/") ? path.substring("/files/".length()) : path;

        try {
            var obj = fileService.get(key);

            // HTML 같은 비정상 바디면 안전 차단
            if (looksLikeHtml(obj.bytes())) {
                return ResponseEntity.status(HttpStatus.BAD_GATEWAY)
                        .contentType(MediaType.TEXT_PLAIN)
                        .body("Upstream returned HTML instead of image for key: " + key);
            }

            String ct = (obj.contentType() == null || obj.contentType().isBlank())
                    ? "application/octet-stream" : obj.contentType();

            byte[] bytes = obj.bytes();

            String filename = key.substring(key.lastIndexOf('/') + 1);
            String encoded = URLEncoder.encode(filename, StandardCharsets.UTF_8).replace("+", "%20");

            return ResponseEntity.ok()
                    .contentType(safeMediaType(ct))
                    .contentLength(bytes.length)
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename*=UTF-8''" + encoded)
                    .cacheControl(CacheControl.maxAge(Duration.ofDays(30)).cachePublic())
                    .body(new ByteArrayResource(bytes));

        } catch (S3FileService.FileNotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .contentType(MediaType.TEXT_PLAIN)
                    .body("Not Found: " + key);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .contentType(MediaType.TEXT_PLAIN)
                    .body("Internal error while fetching: " + key);
        }
    }

    private static MediaType safeMediaType(String ct) {
        try { return MediaType.parseMediaType(ct); }
        catch (Exception e) { return MediaType.APPLICATION_OCTET_STREAM; }
    }

    private static boolean looksLikeHtml(byte[] b) {
        if (b == null || b.length < 5) return false;
        String head = new String(b, 0, Math.min(b.length, 16), StandardCharsets.US_ASCII).trim().toLowerCase();
        return head.startsWith("<!doc") || head.startsWith("<html");
    }
}
