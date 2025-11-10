// com.nemo.backend.domain.file.S3FileService
package com.nemo.backend.domain.file;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.sync.ResponseTransformer;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

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
            // 1) 바디 먼저 받는다
            ResponseBytes<GetObjectResponse> bytes = s3Client.getObject(
                    b -> b.bucket(bucket).key(normalizedKey),
                    ResponseTransformer.toBytes()
            );
            byte[] data = bytes.asByteArray();

            // 2) 헤더는 참고용으로만 본다
            HeadObjectResponse head = s3Client.headObject(b -> b.bucket(bucket).key(normalizedKey));
            String s3Ct = head.contentType();

            // 3) '매직 바이트' 판별 우선
            String detected = detectMime(data);
            String guessedByName = guessFromKey(normalizedKey);

            String ct = (detected != null) ? detected
                    : (isGood(s3Ct) ? s3Ct
                    : (guessedByName != null ? guessedByName : "application/octet-stream"));

            long len = data.length; // 실제 바이트 길이 신뢰

            return new FileObject(data, ct, len);

        } catch (NoSuchKeyException e) {
            throw new FileNotFoundException("S3 object not found: " + key);
        }
    }

    private static boolean isGood(String mime) {
        return mime != null && !mime.isBlank() && !"application/octet-stream".equalsIgnoreCase(mime);
    }

    public static String guessFromKey(String key) {
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

    // 아주 얕은 ‘매직 바이트’ 판별기
    private static String detectMime(byte[] b) {
        if (b == null || b.length < 4) return null;

        // JPEG
        if (b.length >= 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF)
            return "image/jpeg";

        // PNG
        if (b.length >= 8 && b[0]==(byte)0x89 && b[1]==0x50 && b[2]==0x4E && b[3]==0x47
                && b[4]==0x0D && b[5]==0x0A && b[6]==0x1A && b[7]==0x0A)
            return "image/png";

        // WEBP (RIFF .... WEBP)
        if (b.length >= 12 && b[0]=='R' && b[1]=='I' && b[2]=='F' && b[3]=='F'
                && b[8]=='W' && b[9]=='E' && b[10]=='B' && b[11]=='P')
            return "image/webp";

        // ISO-BMFF (ftyp)
        if (b.length >= 12 && b[4]=='f' && b[5]=='t' && b[6]=='y' && b[7]=='p') {
            String brand = new String(new byte[]{b[8], b[9], b[10], b[11]});
            if (brand.startsWith("he") || brand.equals("mif1") || brand.equals("msf1"))
                return "image/heic";
            return "video/mp4"; // 그 외 ISO-BMFF는 대체로 mp4로 본다
        }
        return null;
    }

    public static class FileNotFoundException extends RuntimeException {
        public FileNotFoundException(String msg) { super(msg); }
    }
}
