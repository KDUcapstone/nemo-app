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

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Locale;
import java.util.UUID;

@Primary
@Component
public class S3PhotoStorage implements PhotoStorage {

    private final S3Client s3Client;
    private final String bucket;
    private final boolean createBucketIfMissing;
    private final String region; // 실 S3 사용 시 LocationConstraint 용

    public S3PhotoStorage(
            S3Client s3Client,
            @Value("${app.s3.bucket}") String bucket,
            @Value("${app.s3.createBucketIfMissing:false}") boolean createBucketIfMissing,
            @Value("${app.s3.region:}") String region
    ) {
        this.s3Client = s3Client;
        this.bucket = bucket;
        this.createBucketIfMissing = createBucketIfMissing;
        this.region = region == null ? "" : region.trim();
        ensureBucket();
    }

    private void ensureBucket() {
        try {
            s3Client.headBucket(b -> b.bucket(bucket));
        } catch (S3Exception e) { // 하위 예외(NoSuchBucketException 등)도 여기서 처리
            if (!createBucketIfMissing) return;
            try {
                CreateBucketRequest.Builder builder = CreateBucketRequest.builder().bucket(bucket);
                if (!region.isBlank()) {
                    builder = builder.createBucketConfiguration(
                            CreateBucketConfiguration.builder()
                                    .locationConstraint(BucketLocationConstraint.fromValue(region))
                                    .build()
                    );
                }
                s3Client.createBucket(builder.build());
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
        byte[] data = file.getBytes();

        // HTML/JSON 차단
        if (looksLikeHtmlOrJson(data)) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "이미지/영상 파일이 아닙니다(HTML/JSON 감지)");
        }

        String reported = file.getContentType();
        String detected = detectMime(data);
        String mime = chooseMime(reported, detected, file.getOriginalFilename());

        String key = buildKey(mime, file.getOriginalFilename());

        try {
            PutObjectRequest req = PutObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .contentType(mime)
                    .contentDisposition("inline; filename=\"" + safeFilename(file.getOriginalFilename()) + "\"")
                    .build();

            s3Client.putObject(req, RequestBody.fromBytes(data));
            return key;

        } catch (S3Exception e) {
            throw new StorageException("S3 업로드 실패: " + e.awsErrorDetails().errorMessage(), e);
        } catch (SdkClientException e) {
            throw new StorageException("S3 클라이언트 오류: " + e.getMessage(), e);
        } catch (Exception e) {
            throw new StorageException("파일 저장 실패: " + e.getClass().getSimpleName() + " - " + e.getMessage(), e);
        }
    }

    /** URL 크롤링 등으로 확보한 바이트를 직접 저장 */
    @Override
    public String storeBytes(byte[] data, String originalFilename, String contentType) throws Exception {
        if (data == null || data.length == 0) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "빈 데이터는 저장할 수 없습니다.");
        }
        if (looksLikeHtmlOrJson(data)) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "이미지/영상 대신 HTML/JSON 응답입니다.");
        }

        String detected = detectMime(data);
        String mime = chooseMime(contentType, detected, originalFilename);
        String key = buildKey(mime, originalFilename);

        try {
            PutObjectRequest req = PutObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .contentType(mime)
                    .contentDisposition("inline; filename=\"" + safeFilename(originalFilename) + "\"")
                    .build();

            s3Client.putObject(req, RequestBody.fromBytes(data));
            return key;

        } catch (S3Exception e) {
            throw new StorageException("S3 업로드 실패: " + e.awsErrorDetails().errorMessage(), e);
        } catch (SdkClientException e) {
            throw new StorageException("S3 클라이언트 오류: " + e.getMessage(), e);
        } catch (Exception e) {
            throw new StorageException("파일 저장 실패: " + e.getClass().getSimpleName() + " - " + e.getMessage(), e);
        }
    }


    private String buildKey(String mime, String originalName) {
        String ext = extensionForMime(mime, originalName);
        String today = LocalDate.now().toString();
        return String.format("albums/%s/%s-qr_photo_%d.%s",
                today, UUID.randomUUID(), System.currentTimeMillis(), ext);
    }

    private static String safeFilename(String name) {
        if (name == null || name.isBlank()) return "file";
        return name.replaceAll("[\\r\\n\\\\/\"<>:*?|]", "_");
    }

    // MIME 최종 결정
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

    // 간단 매직넘버 MIME 감지
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

        // HTML/JSON 힌트
        String head = new String(b, 0, Math.min(b.length, 32), StandardCharsets.US_ASCII).trim().toLowerCase();
        if (head.startsWith("<!doc") || head.startsWith("<html") || head.startsWith("{\""))
            return "text/html";

        return null;
    }

    private static boolean looksLikeHtmlOrJson(byte[] b) {
        if (b == null || b.length < 5) return false;
        String head = new String(b, 0, Math.min(b.length, 48), StandardCharsets.US_ASCII).trim().toLowerCase();
        return head.startsWith("<!doc") || head.startsWith("<html") || head.startsWith("{\"") || head.contains("<body");
    }

    private static String extensionForMime(String mime, String originalName) {
        String m = (mime == null) ? "" : mime.toLowerCase(Locale.ROOT);
        if (m.equals("image/jpeg")) return "jpg";
        if (m.equals("image/png"))  return "png";
        if (m.equals("image/webp")) return "webp";
        if (m.equals("image/heic")) return "heic";
        if (m.equals("video/mp4"))  return "mp4";
        if (m.equals("text/html"))  return "html";
        String guessed = guessFromName(originalName);
        if (guessed != null) return extensionForMime(guessed, null);
        return "bin";
    }

    public static class StorageException extends RuntimeException {
        public StorageException(String msg) { super(msg); }
        public StorageException(String msg, Throwable cause) { super(msg, cause); }
    }

    /** S3 객체 삭제 */
    @Override
    public void delete(String key) {
        if (key == null || key.isBlank()) return;

        String normalizedKey = key.startsWith("/") ? key.substring(1) : key;

        try {
            DeleteObjectRequest req = DeleteObjectRequest.builder()
                    .bucket(bucket)
                    .key(normalizedKey)
                    .build();

            s3Client.deleteObject(req);

        } catch (NoSuchKeyException e) {
            // 이미 안 존재하는 경우는 무시
        } catch (S3Exception | SdkClientException e) {
            throw new StorageException("S3 삭제 실패: " + e.getMessage(), e);
        }
    }

    /** S3 객체 크기 조회 (byte 단위) – presigned URL/다운로드 목록에서 용량 보여줄 때 사용 */
    public Long getObjectSize(String key) {
        if (key == null || key.isBlank()) return null;

        String normalizedKey = key.startsWith("/") ? key.substring(1) : key;

        try {
            HeadObjectRequest head = HeadObjectRequest.builder()
                    .bucket(bucket)
                    .key(normalizedKey)
                    .build();
            HeadObjectResponse res = s3Client.headObject(head);
            return res.contentLength();
        } catch (NoSuchKeyException e) {
            // 없는 경우는 그냥 null
            return null;
        } catch (S3Exception | SdkClientException e) {
            throw new StorageException("S3 객체 정보 조회 실패: " + e.getMessage(), e);
        }
    }
}
