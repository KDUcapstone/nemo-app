// com.nemo.backend.domain.file.S3FileService
package com.nemo.backend.domain.file;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.sync.ResponseTransformer;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

import java.nio.charset.StandardCharsets;
import java.util.Locale;

@Service
@RequiredArgsConstructor
public class S3FileService {

    public record FileObject(byte[] bytes, String contentType, Long contentLength) {}

    private final S3Client s3Client;

    @Value("${app.s3.bucket}")
    private String bucket;

    public FileObject get(String key) {
        String normalizedKey = key.startsWith("/") ? key.substring(1) : key;

        try {
            ResponseBytes<GetObjectResponse> bytes = s3Client.getObject(
                    b -> b.bucket(bucket).key(normalizedKey),
                    ResponseTransformer.toBytes()
            );
            byte[] data = bytes.asByteArray();

            // 1) 시그니처로 판독
            String ct = detectMime(data);

            // 2) 시그니처 실패 시 확장자로 보정
            if (ct == null) {
                String guessed = guessFromKey(normalizedKey);
                ct = (guessed != null) ? guessed : "application/octet-stream";
            }

            Long len = (long) data.length;
            return new FileObject(data, ct, len);

        } catch (NoSuchKeyException e) {
            throw new FileNotFoundException("S3 object not found: " + key);
        }
    }

    // === 간단 매직넘버 검사 ===
    private static String detectMime(byte[] b) {
        if (b == null || b.length < 4) return null;

        // JPEG
        if (b.length >= 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF)
            return "image/jpeg";

        // PNG
        if (b.length >= 8 && b[0]==(byte)0x89 && b[1]==0x50 && b[2]==0x4E && b[3]==0x47
                && b[4]==0x0D && b[5]==0x0A && b[6]==0x1A && b[7]==0x0A)
            return "image/png";

        // WEBP
        if (b.length >= 12 && b[0]=='R' && b[1]=='I' && b[2]=='F' && b[3]=='F'
                && b[8]=='W' && b[9]=='E' && b[10]=='B' && b[11]=='P')
            return "image/webp";

        // ISO-BMFF (ftyp) → heic/mp4 등
        if (b.length >= 12 && b[4]=='f' && b[5]=='t' && b[6]=='y' && b[7]=='p') {
            String brand = new String(new byte[]{b[8], b[9], b[10], b[11]}, StandardCharsets.US_ASCII);
            if (brand.startsWith("he") || brand.equals("mif1") || brand.equals("msf1"))
                return "image/heic";
            return "video/mp4";
        }

        // HTML 흔적 → null을 반환(컨트롤러에서 별도 방어)
        String head = new String(b, 0, Math.min(b.length, 16), StandardCharsets.US_ASCII).trim().toLowerCase();
        if (head.startsWith("<!doc") || head.startsWith("<html"))
            return null;

        return null;
    }

    private static String guessFromKey(String key) {
        String k = key.toLowerCase(Locale.ROOT);
        if (k.endsWith(".jpg") || k.endsWith(".jpeg")) return "image/jpeg";
        if (k.endsWith(".png"))  return "image/png";
        if (k.endsWith(".gif"))  return "image/gif";
        if (k.endsWith(".webp")) return "image/webp";
        if (k.endsWith(".heic") || k.endsWith(".heif")) return "image/heic";
        if (k.endsWith(".bmp"))  return "image/bmp";
        if (k.endsWith(".svg"))  return "image/svg+xml";
        if (k.endsWith(".mp4"))  return "video/mp4";
        if (k.endsWith(".webm")) return "video/webm";
        if (k.endsWith(".mov"))  return "video/quicktime";
        return null;
    }

    public static class FileNotFoundException extends RuntimeException {
        public FileNotFoundException(String msg) { super(msg); }
    }
}
