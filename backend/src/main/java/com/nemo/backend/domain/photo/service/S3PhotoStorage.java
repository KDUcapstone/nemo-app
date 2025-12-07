// com.nemo.backend.domain.photo.service.S3PhotoStorage
        package com.nemo.backend.domain.photo.service;

import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.exception.SdkClientException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

import javax.imageio.*;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.ImageOutputStream;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Iterator;
import java.util.Locale;
import java.util.UUID;

@Primary
@Component
@Slf4j
public class S3PhotoStorage implements PhotoStorage {

    private static final int MAX_LONG_EDGE = 2048; // 긴 변 기준 최대 픽셀

    static {
        ImageIO.scanForPlugins();
        boolean hasWriter = ImageIO.getImageWritersByFormatName("webp").hasNext()
                || ImageIO.getImageWritersByMIMEType("image/webp").hasNext();
        log.info("[S3PhotoStorage] WEBP writer available? {}", hasWriter);
    }

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
        long requestSize = file.getSize();
        String originalName = file.getOriginalFilename();

        // 헤더 일부만 읽어서 HTML/JSON, MIME 판별
        byte[] head = readHeadBytes(file, 64 * 1024);

        // HTML/JSON 차단
        if (looksLikeHtmlOrJson(head)) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "이미지/영상 파일이 아닙니다(HTML/JSON 감지)");
        }

        String reported = file.getContentType();
        String detected = detectMime(head);
        String mime = chooseMime(reported, detected, originalName);

        // LOG: 업로드 들어온 원본 정보
        log.info("[S3PhotoStorage] multipart upload start: name={}, requestSize={} bytes, "
                        + "reportedMime={}, detectedMime={}",
                originalName,
                requestSize,
                reported,
                detected
        );

        // 이미지면 압축/변환, 아니면 스트리밍 업로드
        if (isImageMime(mime)) {
            byte[] data = file.getBytes();
            int originalSize = data.length;

            CompressedResult result = compressImageBestEffort(data, originalName, mime);
            data = result.bytes;
            mime = result.mime;

            log.info("[S3PhotoStorage] multipart image result: name={}, originalSize={} bytes, "
                            + "finalSize={} bytes, targetMime={}",
                    originalName,
                    originalSize,
                    data.length,
                    mime
            );

            String key = buildKey(mime, originalName);

            try {
                PutObjectRequest req = PutObjectRequest.builder()
                        .bucket(bucket)
                        .key(key)
                        .contentType(mime)
                        .contentDisposition("inline; filename=\"" + safeFilename(originalName) + "\"")
                        .build();

                s3Client.putObject(req, RequestBody.fromBytes(data));

                // LOG: 최종 업로드 완료
                log.info("[S3PhotoStorage] multipart upload done: key={}, size={} bytes, mime={}",
                        key, data.length, mime);

                return key;

            } catch (S3Exception e) {
                throw new StorageException("S3 업로드 실패: " + e.awsErrorDetails().errorMessage(), e);
            } catch (SdkClientException e) {
                throw new StorageException("S3 클라이언트 오류: " + e.getMessage(), e);
            } catch (Exception e) {
                throw new StorageException("파일 저장 실패: " + e.getClass().getSimpleName() + " - " + e.getMessage(), e);
            }
        } else {
            // 이미지가 아니면 InputStream 스트리밍 방식으로 업로드
            String key = buildKey(mime, originalName);

            try {
                PutObjectRequest req = PutObjectRequest.builder()
                        .bucket(bucket)
                        .key(key)
                        .contentType(mime)
                        .contentDisposition("inline; filename=\"" + safeFilename(originalName) + "\"")
                        .build();

                try (InputStream in = file.getInputStream()) {
                    s3Client.putObject(req, RequestBody.fromInputStream(in, requestSize));
                }

                log.info("[S3PhotoStorage] multipart upload(stream) done: key={}, size={} bytes, mime={}",
                        key, requestSize, mime);

                return key;

            } catch (S3Exception e) {
                throw new StorageException("S3 업로드 실패: " + e.awsErrorDetails().errorMessage(), e);
            } catch (SdkClientException e) {
                throw new StorageException("S3 클라이언트 오류: " + e.getMessage(), e);
            } catch (Exception e) {
                throw new StorageException("파일 저장 실패: " + e.getClass().getSimpleName() + " - " + e.getMessage(), e);
            }
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

        int originalSize = data.length; // LOG용

        // LOG: 바이트 기반 업로드 시작
        log.info("[S3PhotoStorage] byte upload start: name={}, originalSize={} bytes, "
                        + "contentType={}, detectedMime={}",
                originalFilename,
                originalSize,
                contentType,
                detected
        );

        // 이미지면 WEBP → JPEG → PNG 순으로 압축/변환 Best Effort
        if (isImageMime(mime)) {
            CompressedResult result = compressImageBestEffort(data, originalFilename, mime);
            data = result.bytes;
            mime = result.mime;

            log.info("[S3PhotoStorage] byte image result: name={}, originalSize={} bytes, "
                            + "finalSize={} bytes, targetMime={}",
                    originalFilename,
                    originalSize,
                    data.length,
                    mime
            );
        }

        String key = buildKey(mime, originalFilename);

        try {
            PutObjectRequest req = PutObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .contentType(mime)
                    .contentDisposition("inline; filename=\"" + safeFilename(originalFilename) + "\"")
                    .build();

            s3Client.putObject(req, RequestBody.fromBytes(data));

            // LOG: 최종 업로드 완료
            log.info("[S3PhotoStorage] byte upload done: key={}, size={} bytes, mime={}",
                    key, data.length, mime);

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

    /** 어떤 이미지든 일단 "이미지면" 압축 대상 */
    private static boolean isImageMime(String mime) {
        if (mime == null) return false;
        return mime.toLowerCase(Locale.ROOT).startsWith("image/");
    }

    // ---------- 여기부터 압축 Best Effort 로직 ----------
    /**
     * 1) (큰 해상도인 경우) 서브샘플링으로 축소된 해상도로 디코딩
     * 2) 긴 변이 MAX_LONG_EDGE 보다 크면 추가 리사이즈
     * 3) WEBP(품질 0.8) 시도
     * 4) WEBP가 에러나거나 이득이 거의 없으면 JPEG(품질 0.85) 시도
     * 5) 그래도 실패/이득 없음 → PNG 시도
     * 6) 끝까지 안 되면 원본 + 원래 mime 유지
     */
    private CompressedResult compressImageBestEffort(byte[] original, String originalName, String originalMime) {
        int originalSize = original.length;
        BufferedImage work;

        // 1) 원본을 서브샘플링해서 디코딩 (초대형 이미지 OOM 방지)
        try (ImageInputStream iis =
                     ImageIO.createImageInputStream(new ByteArrayInputStream(original))) {

            if (iis == null) {
                throw new StorageException("이미지 스트림 생성 실패: " + originalName, null);
            }

            Iterator<ImageReader> readers = ImageIO.getImageReaders(iis);
            if (!readers.hasNext()) {
                throw new ApiException(ErrorCode.INVALID_ARGUMENT,
                        "지원하지 않는 이미지 형식입니다: " + originalName);
            }

            javax.imageio.ImageReader reader = readers.next();
            try {
                reader.setInput(iis, true, true);

                int w = reader.getWidth(0);
                int h = reader.getHeight(0);
                int longEdge = Math.max(w, h);

                // 말도 안 되게 큰 해상도는 아예 차단 (선택적)
                if (longEdge > 20_000) {
                    throw new ApiException(ErrorCode.INVALID_ARGUMENT,
                            "이미지 해상도가 너무 큽니다 (최대 20000px): " + originalName);
                }

                int subsample = 1;
                if (longEdge > MAX_LONG_EDGE) {
                    subsample = (int) Math.ceil((double) longEdge / MAX_LONG_EDGE);
                }

                ImageReadParam param = reader.getDefaultReadParam();
                if (subsample > 1) {
                    param.setSourceSubsampling(subsample, subsample, 0, 0);
                }

                BufferedImage decoded = reader.read(0, param);
                if (decoded == null) {
                    throw new ApiException(ErrorCode.INVALID_ARGUMENT,
                            "이미지 파일로 읽을 수 없습니다: " + originalName);
                }

                work = resizeIfNecessary(decoded, originalName);

            } finally {
                reader.dispose();
            }

        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            throw new StorageException("이미지 디코딩 실패: " + originalName + " / " + e.getMessage(), e);
        }

        // 2) WEBP 우선 시도
        try {
            byte[] webp = encodeImage(work, "webp", 0.80f);
            if (webp != null && webp.length > 0) {
                double ratio = (double) webp.length / originalSize;
                if (ratio < 0.95) { // 5% 이상 줄어들면 채택
                    int saved = originalSize - webp.length;
                    log.info("WEBP 압축 성공: {} (orig={} bytes -> {} bytes, saved={} bytes, ratio={}%)",
                            originalName, originalSize, webp.length, saved, Math.round(ratio * 100));
                    return new CompressedResult(webp, "image/webp");
                } else {
                    log.debug("WEBP 후보가 원본보다 크거나 이득이 적어 패스: {} (orig={} -> {} bytes, ratio={}%)",
                            originalName, originalSize, webp.length, Math.round(ratio * 100));
                }
            }
        } catch (Exception e) {
            log.warn("WEBP 압축 실패, JPEG 시도: {} / {}", originalName, e.getMessage());
        }

        // 3) JPEG 시도 (투명도 있으면 흰 배경)
        try {
            BufferedImage rgbImage = work;
            if (work.getType() != BufferedImage.TYPE_INT_RGB) {
                rgbImage = new BufferedImage(work.getWidth(), work.getHeight(), BufferedImage.TYPE_INT_RGB);
                Graphics2D g2d = rgbImage.createGraphics();
                g2d.setColor(Color.WHITE);
                g2d.fillRect(0, 0, work.getWidth(), work.getHeight());
                g2d.drawImage(work, 0, 0, null);
                g2d.dispose();
            }

            byte[] jpeg = encodeImage(rgbImage, "jpeg", 0.85f);
            if (jpeg != null && jpeg.length > 0) {
                double ratio = (double) jpeg.length / originalSize;
                if (ratio < 0.98) { // 2% 이상 줄어들면 채택
                    int saved = originalSize - jpeg.length;
                    log.info("JPEG 압축 성공: {} (orig={} bytes -> {} bytes, saved={} bytes, ratio={}%)",
                            originalName, originalSize, jpeg.length, saved, Math.round(ratio * 100));
                    return new CompressedResult(jpeg, "image/jpeg");
                } else {
                    log.debug("JPEG 후보가 원본보다 크거나 이득이 적어 패스: {} (orig={} -> {} bytes, ratio={}%)",
                            originalName, originalSize, jpeg.length, Math.round(ratio * 100));
                }
            }
        } catch (Exception e) {
            log.warn("JPEG 압축 실패, PNG 시도: {} / {}", originalName, e.getMessage());
        }

        // 4) PNG 시도 (대부분의 사진에서는 보통 손해라 거의 안 쓸 가능성 높음)
        try {
            byte[] png = encodeImage(work, "png", null);
            if (png != null && png.length > 0) {
                double ratio = (double) png.length / originalSize;
                if (ratio < 0.98) {
                    int saved = originalSize - png.length;
                    log.info("PNG 압축 성공: {} (orig={} bytes -> {} bytes, saved={} bytes, ratio={}%)",
                            originalName, originalSize, png.length, saved, Math.round(ratio * 100));
                    return new CompressedResult(png, "image/png");
                } else {
                    log.debug("PNG 후보가 원본보다 크거나 이득이 적어 패스: {} (orig={} -> {} bytes, ratio={}%)",
                            originalName, originalSize, png.length, Math.round(ratio * 100));
                }
            }
        } catch (Exception e) {
            log.warn("PNG 압축 실패, 원본 업로드: {} / {}", originalName, e.getMessage());
        }

        // 5) 전부 실패 or 이득 없음 → 원본 그대로
        log.info("압축/변환해도 이득이 없어 원본 유지: {} (size={} bytes, mime={})",
                originalName, originalSize, originalMime);
        String finalMime = isGood(originalMime) ? originalMime : "application/octet-stream";
        return new CompressedResult(original, finalMime);
    }

    /** 긴 변이 MAX_LONG_EDGE 보다 크면 비율 유지해서 리사이즈 */
    private BufferedImage resizeIfNecessary(BufferedImage src, String originalName) {
        int w = src.getWidth();
        int h = src.getHeight();
        int longEdge = Math.max(w, h);

        if (longEdge <= MAX_LONG_EDGE) {
            return src; // 그대로 사용
        }

        double scale = (double) MAX_LONG_EDGE / (double) longEdge;
        int newW = (int) Math.round(w * scale);
        int newH = (int) Math.round(h * scale);

        BufferedImage resized = new BufferedImage(newW, newH, src.getType() == 0
                ? BufferedImage.TYPE_INT_ARGB
                : src.getType());
        Graphics2D g2d = resized.createGraphics();
        g2d.setRenderingHint(java.awt.RenderingHints.KEY_INTERPOLATION,
                java.awt.RenderingHints.VALUE_INTERPOLATION_BICUBIC);
        g2d.drawImage(src, 0, 0, newW, newH, null);
        g2d.dispose();

        log.info("이미지 리사이즈: {} ({}x{} -> {}x{})",
                originalName, w, h, newW, newH);

        return resized;
    }

    private byte[] encodeImage(BufferedImage image, String formatName, Float quality) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageWriter writer = null;
        ImageOutputStream ios = null;
        try {
            // 1) 포맷 이름으로 writer 찾기
            Iterator<ImageWriter> writers = ImageIO.getImageWritersByFormatName(formatName);
            // 2) webp인 경우 MIME 기반으로 한 번 더 시도
            if (!writers.hasNext() && "webp".equalsIgnoreCase(formatName)) {
                writers = ImageIO.getImageWritersByMIMEType("image/webp");
            }
            if (!writers.hasNext()) {
                throw new IllegalStateException("ImageWriter not found for format: " + formatName);
            }

            writer = writers.next();

            if ("webp".equalsIgnoreCase(formatName)) {
                log.info("[WEBP] Using writer implementation: {}", writer.getClass().getName());
            }

            javax.imageio.ImageWriteParam param = writer.getDefaultWriteParam();

            if (quality != null && param.canWriteCompressed()) {
                param.setCompressionMode(javax.imageio.ImageWriteParam.MODE_EXPLICIT);

                // compressionType 먼저 지정
                String[] types = param.getCompressionTypes();
                if (types != null && types.length > 0) {
                    String chosen = types[0];
                    for (String t : types) {
                        if (t != null && t.toLowerCase(Locale.ROOT).contains("lossy")) {
                            chosen = t;
                            break;
                        }
                    }
                    param.setCompressionType(chosen);
                }

                param.setCompressionQuality(quality); // 0.0 ~ 1.0
            }

            ios = ImageIO.createImageOutputStream(out);
            writer.setOutput(ios);
            writer.write(null, new IIOImage(image, null, null), param);

            byte[] encoded = out.toByteArray();

            if ("webp".equalsIgnoreCase(formatName)) {
                log.info("[WEBP] Encoded size={} bytes (quality={})", encoded.length, quality);
            }

            // 0바이트면 실패로 간주
            if (encoded.length == 0) {
                throw new IllegalStateException("Encoded image is empty for format: " + formatName);
            }

            return encoded;
        } finally {
            if (ios != null) ios.close();
            if (writer != null) writer.dispose();
            out.close();
        }
    }

    private byte[] readHeadBytes(MultipartFile file, int maxBytes) throws Exception {
        try (InputStream in = file.getInputStream();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buf = new byte[4096];
            int total = 0;
            int r;
            while ((r = in.read(buf)) != -1 && total < maxBytes) {
                int len = Math.min(r, maxBytes - total);
                out.write(buf, 0, len);
                total += len;
                if (total >= maxBytes) break;
            }
            return out.toByteArray();
        }
    }

    private static class CompressedResult {
        final byte[] bytes;
        final String mime;

        CompressedResult(byte[] bytes, String mime) {
            this.bytes = bytes;
            this.mime = mime;
        }
    }

    public static class StorageException extends RuntimeException {
        public StorageException(String msg) { super(msg); }
        public StorageException(String msg, Throwable cause) { super(msg, cause); }
    }

    /** S3 객체 삭제 */
    @Override
    public void delete(String storedFilename) {
        try {
            DeleteObjectRequest request = DeleteObjectRequest.builder()
                    .bucket(bucket)
                    .key(storedFilename)
                    .build();

            s3Client.deleteObject(request);

            log.info("[S3] deleted file={}", storedFilename);

        } catch (Exception e) {
            throw new StorageException("Failed to delete S3 object", e);
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
