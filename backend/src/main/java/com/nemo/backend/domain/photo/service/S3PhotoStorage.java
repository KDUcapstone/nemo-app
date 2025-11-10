// com.nemo.backend.domain.photo.service.S3PhotoStorage
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
import java.util.Locale;
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
        ensureBucket();
    }

    private void ensureBucket() {
        try {
            s3Client.headBucket(b -> b.bucket(bucket));
        } catch (S3Exception e) {
            if (!createBucketIfMissing) return;
            try {
                s3Client.createBucket(b -> b.bucket(bucket));
            } catch (S3Exception ce) {
                throw new ApiException(ErrorCode.STORAGE_FAILED,
                        "S3 버킷 생성 실패: " + ce.awsErrorDetails().errorMessage(), ce);
            }
        } catch (SdkClientException e) {
            throw new ApiException(ErrorCode.STORAGE_FAILED, "S3 연결 실패: " + e.getMessage(), e);
        }
    }

    @Override
    public String store(MultipartFile file) throws Exception {
        byte[] data = file.getBytes();                    // 한 번만 읽어서 재사용
        String reported = file.getContentType();          // 클라이언트가 보낸 MIME
        String detected = detectMime(data);               // 시그니처로 감지
        String mime = chooseMime(reported, detected, file.getOriginalFilename());

        String ext = extensionForMime(mime, file.getOriginalFilename());
        String today = LocalDate.now().toString();
        String key = String.format(
                "albums/%s/%s-qr_photo_%d.%s",
                today, UUID.randomUUID(), System.currentTimeMillis(), ext
        );

        try {
            PutObjectRequest req = PutObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .contentType(mime)                    // 정확한 MIME
                    .contentDisposition("inline; filename=\"" + safeFilename(file.getOriginalFilename()) + "\"")
                    .build();

            s3Client.putObject(req, RequestBody.fromBytes(data));
            return key;

        } catch (S3Exception e) {
            throw new StorageException("S3 업로드 실패: " + e.awsErrorDetails().errorMessage(), e);
        } catch (SdkClientException e) {
            throw new StorageException("S3 클라이언트 오류: " + e.getMessage(), e);
        } catch (Exception e) {
            throw new StorageException("파일 저장 실패", e);
        }
    }

    private static String safeFilename(String name) {
        if (name == null) return "file";
        return name.replaceAll("[\\r\\n\\\\/\"<>:*?|]", "_");
    }

    // ── MIME 최종 결정: reported > detected > filename 추정 > 기본값 ──
    private static String chooseMime(String reported, String detected, String originalName) {
        if (isGood(reported)) return reported;
        if (isGood(detected)) return detected;
        String guessed = guessFromName(originalName);
        if (isGood(guessed)) return guessed;
        return "application/octet-stream";
    }

    private static boolean isGood(String mime) {
        return mime != null && !mime.isBlank() && !"application/octet-stream".equalsIgnoreCase(mime);
    }

    private static String guessFromName(String name) {
        if (name == null) return null;
        String n = name.toLowerCase(Locale.ROOT);
        if (n.endsWith(".jpg") || n.endsWith(".jpeg")) return "image/jpeg";
        if (n.endsWith(".png"))  return "image/png";
        if (n.endsWith(".gif"))  return "image/gif";
        if (n.endsWith(".webp")) return "image/webp";
        if (n.endsWith(".heic") || n.endsWith(".heif")) return "image/heic";
        if (n.endsWith(".mp4"))  return "video/mp4";
        return null;
    }

    // ── 시그니처 감지(HEIC/WEBP/PNG/JPEG/MP4) ──
    private static String detectMime(byte[] b) {
        if (b == null || b.length < 4) return null;

        // JPEG
        if (b.length >= 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF)
            return "image/jpeg";

        // PNG
        if (b.length >= 8 && b[0]==(byte)0x89 && b[1]==0x50 && b[2]==0x4E && b[3]==0x47
                && b[4]==0x0D && b[5]==0x0A && b[6]==0x1A && b[7]==0x0A)
            return "image/png";

        // WEBP (RIFF....WEBP)
        if (b.length >= 12 && b[0]=='R' && b[1]=='I' && b[2]=='F' && b[3]=='F'
                && b[8]=='W' && b[9]=='E' && b[10]=='B' && b[11]=='P')
            return "image/webp";

        // ISO-BMFF (ftyp)
        if (b.length >= 12 && b[4]=='f' && b[5]=='t' && b[6]=='y' && b[7]=='p') {
            // major/compatible brands에 heic/heix/heif/heim/avif 등 포함 가능
            String brand = new String(new byte[]{b[8], b[9], b[10], b[11]});
            if (brand.startsWith("he") || brand.equals("mif1") || brand.equals("msf1"))
                return "image/heic";          // HEIC/HEIF
            return "video/mp4";               // 그 외는 mp4로 간주
        }

        return null;
    }

    // ── 확장자 매핑(HEIC/HEIF 지원) ──
    private static String extensionForMime(String mime, String originalName) {
        String m = (mime == null) ? "" : mime.toLowerCase(Locale.ROOT);
        if (m.equals("image/jpeg")) return "jpg";
        if (m.equals("image/png"))  return "png";
        if (m.equals("image/webp")) return "webp";
        if (m.equals("image/heic")) return "heic";
        if (m.equals("video/mp4"))  return "mp4";
        // reported/detected가 모두 애매하면 원래 확장자 유지 시도
        String guessed = guessFromName(originalName);
        if (guessed != null) return extensionForMime(guessed, null);
        return "bin";
    }
}
