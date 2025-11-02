package com.nemo.backend.domain.photo.service;

import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.domain.photo.repository.PhotoRepository;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;   // ✅ 이 import가 꼭 필요
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.CookieHandler;
import java.net.CookieManager;
import java.net.CookiePolicy;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
@Transactional
public class PhotoServiceImpl implements PhotoService {

    private static final int CONNECT_TIMEOUT_MS = 5000;
    private static final int READ_TIMEOUT_MS    = 10000;
    private static final int MAX_REDIRECTS      = 5;
    private static final int MAX_HTML_FOLLOW    = 2;
    private static final long MAX_BYTES         = 50L * 1024 * 1024;
    private static final String USER_AGENT      = "nemo-app/1.0 (+https://nemo)";

    private final PhotoRepository photoRepository;
    private final PhotoStorage storage;

    // ✅ 앱이 외부에서 접근할 때 사용할 베이스 URL (에뮬레이터면 10.0.2.2:8080)
    private final String publicBaseUrl;

    @Autowired
    public PhotoServiceImpl(PhotoRepository photoRepository,
                            PhotoStorage storage,
                            @Value("${app.public-base-url:http://localhost:8080}") String publicBaseUrl) {
        this.photoRepository = photoRepository;
        this.storage = storage;
        this.publicBaseUrl = stripTrailingSlash(publicBaseUrl);
    }

    private static String stripTrailingSlash(String s) {
        return (s != null && s.endsWith("/")) ? s.substring(0, s.length() - 1) : s;
    }

    private String toPublicUrl(String key) {
        // /files/{key}를 절대 URL로 변환
        return publicBaseUrl + "/files/" + key;
    }

    @Override
    public PhotoResponseDto uploadHybrid(Long userId,
                                         String qrCode,
                                         MultipartFile image,
                                         String brand,
                                         String location,
                                         LocalDateTime takenAt,
                                         String tagListJson,
                                         String friendIdListJson,
                                         String memo) {
        if (qrCode == null || qrCode.isBlank()) {
            throw new IllegalArgumentException("qrCode is required.");
        }

        String qrHash = sha256Hex(qrCode);
        photoRepository.findByQrHash(qrHash)
                .ifPresent(p -> { throw new DuplicateQrException("이미 업로드된 QR입니다."); });

        String storedImage = null;
        String storedThumb = null;
        String storedVideo = null;

        try {
            if (image != null && !image.isEmpty()) {
                String key = storage.store(image);     // S3 key
                String url = toPublicUrl(key);         // /files/{key}
                storedImage = url;
                storedThumb = url;
            } else {
                if (looksLikeUrl(qrCode)) {
                    AssetPair ap = fetchAssetsFromQrPayload(qrCode);
                    storedImage = ap.imageUrl;
                    storedThumb = (ap.thumbnailUrl != null) ? ap.thumbnailUrl : ap.imageUrl;
                    storedVideo = ap.videoUrl;
                    if (takenAt == null) takenAt = ap.takenAt;
                } else {
                    throw new InvalidQrException("지원하지 않는 QR 포맷입니다.");
                }
            }
        } catch (ExpiredQrException | InvalidQrException e) {
            throw e;
        } catch (Exception e) {
            throw new ExpiredQrException("QR 자원을 가져오는 데 실패했습니다.", e);
        }

        if (brand == null || brand.isBlank()) brand = inferBrand(qrCode);
        if (takenAt == null) takenAt = LocalDateTime.now();

        Photo photo = new Photo(
                userId,
                null,
                storedImage,
                storedThumb,
                storedVideo,
                qrHash,
                brand,
                takenAt,
                null
        );
        Photo saved = photoRepository.save(photo);
        return new PhotoResponseDto(saved);
    }

    // 목록/삭제(인터페이스 미구현 오류 해결)
    @Override
    @Transactional(readOnly = true)
    public Page<PhotoResponseDto> list(Long userId, Pageable pageable) {
        return photoRepository
                .findByUserIdAndDeletedIsFalseOrderByCreatedAtDesc(userId, pageable)
                .map(PhotoResponseDto::new);
    }

    @Override
    public void delete(Long userId, Long photoId) {
        Photo photo = photoRepository.findById(photoId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 사진입니다."));
        if (!photo.getUserId().equals(userId)) throw new IllegalStateException("삭제 권한이 없습니다.");
        photo.setDeleted(true);
        photoRepository.save(photo);
    }

    // ---------- QR/네트워크 처리 ----------
    private AssetPair fetchAssetsFromQrPayload(String startUrl) throws IOException {
        CookieManager cm = new CookieManager(null, CookiePolicy.ACCEPT_ALL);
        CookieHandler.setDefault(cm);

        String current = startUrl;
        int htmlFollow = 0;
        String foundImage = null, foundVideo = null, foundThumb = null;

        for (int redirects = 0; redirects <= MAX_REDIRECTS; redirects++) {
            URL url = new URL(current);
            HttpURLConnection conn = open(current, "GET", null, startUrl);
            int code = conn.getResponseCode();

            if (code / 100 == 3) {
                String location = conn.getHeaderField("Location");
                if (location == null || location.isBlank()) throw new IOException("Redirect without Location");
                current = new URL(url, location).toString();
                continue;
            }

            String contentType = safeLower(conn.getContentType());
            String cd = conn.getHeaderField("Content-Disposition");
            boolean isAttachment = cd != null && cd.toLowerCase(Locale.ROOT).contains("attachment");

            if ((contentType != null && (contentType.startsWith("image/") || contentType.startsWith("video/"))) || isAttachment) {
                try (InputStream in = boundedStream(conn)) {
                    String ct = (contentType != null) ? contentType : "application/octet-stream";
                    String ext = extractExtensionFromContentType(ct);
                    MultipartFile mf = toMultipart(in, ct, ext);
                    String key = storage.store(mf);
                    String urlStr = toPublicUrl(key);

                    if (ct.startsWith("image/")) {
                        if (foundImage == null) foundImage = urlStr;
                        if (foundThumb == null)  foundThumb  = urlStr;
                    } else if (ct.startsWith("video/")) {
                        if (foundVideo == null) foundVideo = urlStr;
                    }
                } catch (Exception e) {
                    throw new IOException(e);
                }
                break;
            }

            if (contentType != null && contentType.startsWith("text/html")) {
                if (htmlFollow >= MAX_HTML_FOLLOW) break;
                String html = readAll(conn.getInputStream()); // ← 유틸 복구
                HtmlExtracted he = extractFromHtml(html, current);
                if (he.imageUrl != null && foundImage == null) foundImage = downloadToStorage(he.imageUrl, startUrl);
                if (he.thumbnailUrl != null && foundThumb == null) foundThumb = downloadToStorage(he.thumbnailUrl, startUrl);
                if (he.videoUrl != null && foundVideo == null) foundVideo = downloadToStorage(he.videoUrl, startUrl);
                if (he.nextGetUrl != null) {
                    current = new URL(url, he.nextGetUrl).toString();
                    htmlFollow++;
                    continue;
                }
                break;
            }
            break;
        }

        if (foundImage == null && foundVideo == null) throw new IOException("이미지/영상 URL을 찾지 못했습니다.");
        if (foundThumb == null) foundThumb = foundImage;
        return new AssetPair(foundImage, foundThumb, foundVideo, null);
    }

    private String downloadToStorage(String absOrRelUrl, String referer) throws IOException {
        URL abs = new URL(new URL(referer), absOrRelUrl);
        HttpURLConnection conn = open(abs.toString(), "GET", null, referer);
        String contentType = safeLower(conn.getContentType());
        try (InputStream in = boundedStream(conn)) {
            String ct = contentType != null ? contentType : "application/octet-stream";
            String ext = extractExtensionFromContentType(ct);
            MultipartFile mf = toMultipart(in, ct, ext);
            String key = storage.store(mf);
            return toPublicUrl(key);
        } catch (Exception e) {
            throw new IOException(e);
        }
    }

    private HttpURLConnection open(String url, String method, String body, String referer) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setInstanceFollowRedirects(false);
        conn.setConnectTimeout(CONNECT_TIMEOUT_MS);
        conn.setReadTimeout(READ_TIMEOUT_MS);
        conn.setRequestProperty("User-Agent", USER_AGENT);
        conn.setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml,image/*,video/*,*/*;q=0.8");
        if (referer != null) conn.setRequestProperty("Referer", referer);
        conn.setRequestMethod(method);
        if ("POST".equalsIgnoreCase(method) && body != null) {
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8");
            conn.setRequestProperty("Content-Length", String.valueOf(bytes.length));
            try (OutputStream os = conn.getOutputStream()) { os.write(bytes); }
        }
        conn.connect();
        return conn;
    }

    private record AssetPair(String imageUrl, String thumbnailUrl, String videoUrl, LocalDateTime takenAt) {}

    // ---------- 유틸 ----------
    private String extractExtensionFromContentType(String contentType) {
        if (contentType == null) return ".bin";
        int slash = contentType.indexOf('/');
        if (slash >= 0 && slash + 1 < contentType.length()) {
            String subtype = contentType.substring(slash + 1).toLowerCase(Locale.ROOT);
            if (subtype.contains("jpeg") || subtype.contains("jpg")) return ".jpg";
            if (subtype.contains("png"))  return ".png";
            if (subtype.contains("gif"))  return ".gif";
            if (subtype.contains("webp")) return ".webp";
            if (subtype.contains("mp4"))  return ".mp4";
            if (subtype.contains("webm")) return ".webm";
            if (subtype.contains("mov"))  return ".mov";
            return "." + subtype.replaceAll("[^a-z0-9.+-]", "");
        }
        return ".bin";
    }

    private String safeLower(String s) { return (s == null) ? null : s.toLowerCase(Locale.ROOT); }

    private String sha256Hex(String input) {
        try {
            var md = java.security.MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(input.getBytes()));
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private boolean looksLikeUrl(String s) {
        String t = s.trim().toLowerCase(Locale.ROOT);
        return t.startsWith("http://") || t.startsWith("https://");
    }

    // ★ 누락돼서 에러 나던 부분
    private String readAll(InputStream in) throws IOException {
        try (in) {
            byte[] buf = in.readAllBytes();
            return new String(buf, StandardCharsets.UTF_8);
        }
    }

    private HtmlExtracted extractFromHtml(String html, String baseUrl) {
        Document doc = Jsoup.parse(html, baseUrl);
        HtmlExtracted out = new HtmlExtracted();

        out.imageUrl = firstMeta(doc,
                "meta[property=og:image]", "meta[name=og:image]",
                "meta[property=og:image:url]", "meta[property=og:image:secure_url]",
                "meta[name=twitter:image]", "meta[itemprop=image]"
        );
        out.thumbnailUrl = firstMeta(doc, "meta[property=og:image:thumbnail]", "meta[name=thumbnail]");
        out.videoUrl = firstMeta(doc,
                "meta[property=og:video]", "meta[name=og:video]",
                "meta[property=og:video:url]", "meta[property=og:video:secure_url]",
                "meta[name=twitter:player]"
        );

        Elements links = doc.select("a[download], a#download, a.button, a, button, .btn, .button");
        for (Element el : links) {
            String href = el.attr("href");
            if (href != null && !href.isBlank()) {
                if (out.imageUrl == null && href.toLowerCase(Locale.ROOT).contains("image")) {
                    out.imageUrl = href;
                }
            }
        }
        if (out.imageUrl == null) {
            Element img = doc.selectFirst("img[src]");
            if (img != null) out.imageUrl = img.attr("src");
        }
        return out;
    }

    private String firstMeta(Document doc, String... selectors) {
        for (String sel : selectors) {
            Element el = doc.selectFirst(sel);
            if (el != null) {
                String c = el.attr("content");
                if (c != null && !c.isBlank()) return c;
            }
        }
        return null;
    }

    private String inferBrand(String urlOrPayload) {
        String s = urlOrPayload.toLowerCase(Locale.ROOT);
        if (s.contains("life4cut") || s.contains("인생네컷")) return "인생네컷";
        if (s.contains("harufilm") || s.contains("하루필름")) return "하루필름";
        if (s.contains("photoism")) return "포토이즘";
        if (s.contains("signature")) return "포토시그니쳐";
        if (s.contains("twin")) return "트윈포토";
        return "기타";
    }

    private static class HtmlExtracted {
        String imageUrl;
        String thumbnailUrl;
        String videoUrl;
        String nextGetUrl;
    }

    private InputStream boundedStream(HttpURLConnection conn) throws IOException {
        long len = conn.getContentLengthLong();
        if (len > 0 && len > MAX_BYTES) throw new IOException("File too large: " + len);
        return new LimitedInputStream(conn.getInputStream(), MAX_BYTES);
    }

    private MultipartFile toMultipart(InputStream in, String contentType, String ext) throws IOException {
        byte[] data = in.readAllBytes();
        if (data.length > MAX_BYTES) throw new IOException("File too large after download");
        return new MultipartFile() {
            @Override public String getName() { return "file"; }
            @Override public String getOriginalFilename() { return java.util.UUID.randomUUID() + ext; }
            @Override public String getContentType() { return contentType; }
            @Override public boolean isEmpty() { return data.length == 0; }
            @Override public long getSize() { return data.length; }
            @Override public byte[] getBytes() { return data; }
            @Override public InputStream getInputStream() { return new java.io.ByteArrayInputStream(data); }
            @Override public void transferTo(java.io.File dest) throws IOException {
                try (var fos = new java.io.FileOutputStream(dest)) { fos.write(data); }
            }
        };
    }

    private static class LimitedInputStream extends java.io.FilterInputStream {
        private long remaining;
        protected LimitedInputStream(InputStream in, long maxBytes) { super(in); this.remaining = maxBytes; }
        @Override public int read() throws IOException {
            if (remaining <= 0) throw new IOException("Limit exceeded");
            int b = super.read(); if (b != -1) remaining--; return b;
        }
        @Override public int read(byte[] b, int off, int len) throws IOException {
            if (remaining <= 0) throw new IOException("Limit exceeded");
            len = (int)Math.min(len, remaining);
            int n = super.read(b, off, len);
            if (n > 0) remaining -= n;
            return n;
        }
    }
}
