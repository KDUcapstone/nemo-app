// com.nemo.backend.domain.photo.service.PhotoServiceImpl
package com.nemo.backend.domain.photo.service;

import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.domain.photo.repository.PhotoRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static com.nemo.backend.domain.photo.service.S3PhotoStorage.StorageException;

@Service
@Transactional
public class PhotoServiceImpl implements PhotoService {

    private static final int CONNECT_TIMEOUT_MS = 5000;
    private static final int READ_TIMEOUT_MS    = 10000;
    private static final int MAX_REDIRECTS      = 5;
    private static final int MAX_HTML_FOLLOW    = 2;   // 필요 시 4까지 늘릴 수 있음
    private static final long MAX_BYTES         = 50L * 1024 * 1024;
    private static final String USER_AGENT      = "Mozilla/5.0 Nemo/1.0";
    private static final int MIN_IMAGE_BYTES    = 5 * 1024;

    private final PhotoRepository photoRepository;
    private final PhotoStorage storage;
    private final String publicBaseUrl;

    public PhotoServiceImpl(PhotoRepository photoRepository,
                            PhotoStorage storage,
                            @Value("${app.public-base-url:http://localhost:8080}") String publicBaseUrl) {
        this.photoRepository = photoRepository;
        this.storage = storage;
        this.publicBaseUrl = publicBaseUrl.replaceAll("/+$", "");
    }

    private String toPublicUrl(String key) {
        return String.format("%s/files/%s", publicBaseUrl, key);
    }

    @Override
    public PhotoResponseDto uploadHybrid(Long userId,
                                         String qrUrlOrPayload,
                                         MultipartFile image,
                                         String brand,
                                         String location,
                                         LocalDateTime takenAt,
                                         String tagListJson,
                                         String friendIdListJson,
                                         String memo) {

        if ((qrUrlOrPayload == null || qrUrlOrPayload.isBlank()) && (image == null || image.isEmpty())) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "image 또는 qrUrl/qrCode 중 하나는 필수입니다.");
        }

        // 중복 QR 차단: URL/QR 문자열이 있을 때만
        if (qrUrlOrPayload != null && !qrUrlOrPayload.isBlank()) {
            String qrHash = sha256Hex(qrUrlOrPayload);
            photoRepository.findByQrHash(qrHash)
                    .ifPresent(p -> { throw new ApiException(ErrorCode.CONFLICT, "이미 업로드된 QR입니다."); });
        }

        String storedImage;
        String storedThumb;
        String storedVideo = null;

        if (image != null && !image.isEmpty()) {
            // A) 직접 파일 업로드
            try {
                String key = storage.store(image);
                String url = toPublicUrl(key);
                storedImage = url;
                storedThumb = url;
            } catch (Exception e) {
                throw new StorageException("파일 저장 실패", e);
            }
        } else {
            // B) URL/QR 경로: 원격 추출
            if (!looksLikeUrl(qrUrlOrPayload)) {
                throw new ApiException(ErrorCode.INVALID_ARGUMENT, "지원하지 않는 QR/URL 포맷입니다.");
            }
            AssetPair ap = fetchAssetsFromQrPayload(qrUrlOrPayload);
            storedImage = ap.imageUrl;
            storedThumb = ap.thumbnailUrl != null ? ap.thumbnailUrl : ap.imageUrl;
            storedVideo = ap.videoUrl;
            if (takenAt == null) takenAt = ap.takenAt;
        }

        if (brand == null || brand.isBlank()) {
            brand = (qrUrlOrPayload != null) ? inferBrand(qrUrlOrPayload) : "기타";
        }
        if (takenAt == null) takenAt = LocalDateTime.now();

        String qrHash = (qrUrlOrPayload != null && !qrUrlOrPayload.isBlank()) ? sha256Hex(qrUrlOrPayload) : null;

        Photo photo = new Photo(userId, null, storedImage, storedThumb, storedVideo, qrHash, brand, takenAt, null);
        Photo saved = photoRepository.save(photo);
        return new PhotoResponseDto(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<PhotoResponseDto> list(Long userId, Pageable pageable) {
        return photoRepository.findByUserIdAndDeletedIsFalseOrderByCreatedAtDesc(userId, pageable)
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

    // ===================== 네트워크/QR 파싱 =====================

    private AssetPair fetchAssetsFromQrPayload(String startUrl) {
        try {
            CookieManager cm = new CookieManager(null, CookiePolicy.ACCEPT_ALL);
            CookieHandler.setDefault(cm);

            LinkedHashSet<String> visited = new LinkedHashSet<>();
            String current = startUrl;
            int htmlFollow = 0;
            String foundImage = null, foundVideo = null, foundThumb = null;

            for (int redirects = 0; redirects <= MAX_REDIRECTS; redirects++) {
                String norm = normalizeUrl(current);
                if (!visited.add(norm)) throw new IOException("Redirect loop: " + current);

                URL url = new URL(current);
                HttpURLConnection conn = open(current, "GET", null, startUrl);
                int code = conn.getResponseCode();

                if (code / 100 == 3) {
                    String location = conn.getHeaderField("Location");
                    if (location == null || location.isBlank()) throw new IOException("Redirect without Location");
                    current = new URL(url, location).toString();
                    continue;
                }
                if (code < 200 || code >= 300) throw new IOException("HTTP " + code + " from " + current);

                String contentType = safeLower(conn.getContentType());
                String cd = conn.getHeaderField("Content-Disposition");
                boolean isAttachment = cd != null && cd.toLowerCase(Locale.ROOT).contains("attachment");

                if ((contentType != null && (contentType.startsWith("image/") || contentType.startsWith("video/"))) || isAttachment) {
                    try (InputStream in = boundedStream(conn)) {
                        byte[] data = in.readAllBytes();
                        String ct = (contentType != null) ? contentType : "application/octet-stream";

                        if (ct.startsWith("image/")) {
                            ensureValidImageBytes(data);
                            ct = sniffContentType(data, ct);
                            String key = storage.storeBytes(data, filenameFromHeadersOrUrl(url, cd, ct), ct);
                            String urlStr = toPublicUrl(key);
                            if (foundImage == null) foundImage = urlStr;
                            if (foundThumb == null)  foundThumb  = urlStr;
                        } else if (ct.startsWith("video/")) {
                            String key = storage.storeBytes(data, filenameFromHeadersOrUrl(url, cd, ct), ct);
                            String urlStr = toPublicUrl(key);
                            if (foundVideo == null) foundVideo = urlStr;
                        }
                    } catch (Exception e) {
                        throw new StorageException("파일 저장 실패", e);
                    }
                    break;
                }

                if (contentType != null && contentType.startsWith("text/html")) {
                    if (htmlFollow >= MAX_HTML_FOLLOW) break;
                    String html = readAll(conn.getInputStream());
                    HtmlExtracted he = extractFromHtml(html, current);
                    if (he.imageUrl != null && !isSamePage(he.imageUrl, current)) {
                        current = new URL(url, he.imageUrl).toString();
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
        } catch (StorageException e) {
            throw e;
        } catch (Exception e) {
            throw new ApiException(ErrorCode.UPSTREAM_FAILED, "원격 자산 추출 실패: " + e.getMessage(), e);
        }
    }

    private HttpURLConnection open(String url, String method, String body, String referer) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setInstanceFollowRedirects(false);
        conn.setConnectTimeout(CONNECT_TIMEOUT_MS);
        conn.setReadTimeout(READ_TIMEOUT_MS);
        conn.setRequestProperty("User-Agent", USER_AGENT);
        conn.setRequestProperty("Accept", "image/jpeg,image/png,image/webp;q=0.9,text/html;q=0.8,*/*;q=0.5");
        conn.setRequestProperty("Accept-Language", "ko,en;q=0.8");
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

    // ===================== HTML 파서 & 유틸 =====================

    private HtmlExtracted extractFromHtml(String html, String baseUrl) {
        Document doc = Jsoup.parse(html, baseUrl);
        HtmlExtracted out = new HtmlExtracted();

        // 1) 다운로드 링크 우선
        Element aDownload = doc.selectFirst(
                "a[download], a[href*='download'], a.btn-download, a#download, a.button, " +
                        "a[href$='.jpg'], a[href$='.jpeg'], a[href$='.png'], a[href$='.webp'], " +
                        "a[href$='.mp4'], a[href$='.webm'], a[href$='.mov']"
        );
        if (aDownload != null) out.imageUrl = aDownload.absUrl("href");

        // 2) picture > source[srcset] (JPEG 우선)
        if (out.imageUrl == null) {
            Element jpeg = doc.selectFirst("picture source[type*=jpeg][srcset], picture source[type*=jpg][srcset]");
            Element any  = (jpeg != null) ? jpeg : doc.selectFirst("picture source[srcset]");
            if (any != null) out.imageUrl = pickBestFromSrcset(any.attr("srcset"), doc.baseUri());
        }

        // 3) img[srcset]
        if (out.imageUrl == null) {
            Element imgSrcset = doc.selectFirst("img[srcset]");
            if (imgSrcset != null) out.imageUrl = pickBestFromSrcset(imgSrcset.attr("srcset"), imgSrcset.baseUri());
        }

        // 4) JSON-LD
        if (out.imageUrl == null) {
            for (Element s : doc.select("script[type=application/ld+json]")) {
                String j = s.data();
                String u = firstUrlFromJsonLd(j);
                if (u != null) { out.imageUrl = u; break; }
            }
        }

        // 5) video poster/source
        if (out.imageUrl == null) {
            Element video = doc.selectFirst("video[poster]");
            if (video != null) out.imageUrl = video.absUrl("poster");
            if (out.imageUrl == null) {
                Element vsrc = doc.selectFirst("video source[src]");
                if (vsrc != null) out.imageUrl = vsrc.absUrl("src");
            }
        }

        // 6) og:image (fallback)
        if (out.imageUrl == null) {
            Element og = doc.selectFirst("meta[property=og:image], meta[name=og:image], meta[itemprop=image]");
            if (og != null) out.imageUrl = og.attr("abs:content");
        }

        // 7) 일반 img[src]
        if (out.imageUrl == null) {
            Element img = doc.selectFirst("img[src]");
            if (img != null) out.imageUrl = img.absUrl("src");
        }

        if (out.imageUrl != null && isSamePage(out.imageUrl, baseUrl)) out.imageUrl = null;
        return out;
    }

    private String pickBestFromSrcset(String srcset, String base) {
        if (srcset == null || srcset.isBlank()) return null;
        String[] parts = srcset.split(",");
        int bestW = -1;
        String bestUrl = null;
        for (String p : parts) {
            String[] tok = p.trim().split("\\s+");
            if (tok.length == 0) continue;
            String url = tok[0];
            int w = -1;
            if (tok.length > 1 && tok[1].endsWith("w")) {
                try { w = Integer.parseInt(tok[1].substring(0, tok[1].length()-1)); } catch (Exception ignored) {}
            }
            if (w > bestW) { bestW = w; bestUrl = url; }
        }
        if (bestUrl == null) return null;
        try { return new URL(new URL(base), bestUrl).toString(); } catch (Exception e) { return bestUrl; }
    }

    private String firstUrlFromJsonLd(String json) {
        if (json == null || json.isBlank()) return null;
        Pattern p = Pattern.compile("(https?:\\\\?/\\\\?/[^\"']+?\\.(?:jpg|jpeg|png|webp|mp4|webm|mov))",
                Pattern.CASE_INSENSITIVE);
        Matcher m = p.matcher(json);
        String best = null;
        while (m.find()) {
            String u = m.group(1).replace("\\/", "/");
            if (best == null || u.length() > best.length()) best = u;
        }
        return best;
    }

    // 파일명 추출(중복 방지용: 래퍼 + 오버로드 한 쌍만 유지)
    private String filenameFromHeadersOrUrl(URL base, String cdHeader, String contentType) {
        return filenameFromHeadersOrUrl(base, cdHeader, contentType, true);
    }
    private String filenameFromHeadersOrUrl(URL base, String cdHeader, String contentType, boolean addExtIfMissing) {
        if (cdHeader != null) {
            Matcher m1 = Pattern.compile("filename\\*=UTF-8''([^;]+)", Pattern.CASE_INSENSITIVE).matcher(cdHeader);
            if (m1.find()) return decodeRFC5987(m1.group(1));
            Matcher m2 = Pattern.compile("filename=\"?([^\";]+)\"?", Pattern.CASE_INSENSITIVE).matcher(cdHeader);
            if (m2.find()) return m2.group(1);
        }
        String path = base.getPath();
        String last = (path == null || path.isBlank()) ? "file" : path.substring(path.lastIndexOf('/') + 1);
        if (last.isBlank()) last = "file";
        if (addExtIfMissing) {
            String low = last.toLowerCase(Locale.ROOT);
            if (!low.contains(".")) {
                if (contentType != null) {
                    if (contentType.contains("jpeg") || contentType.contains("jpg")) last += ".jpg";
                    else if (contentType.contains("png"))  last += ".png";
                    else if (contentType.contains("webp")) last += ".webp";
                    else if (contentType.contains("mp4"))  last += ".mp4";
                }
            }
        }
        return last;
    }

    private String decodeRFC5987(String s) {
        try { return URLDecoder.decode(s, StandardCharsets.UTF_8); }
        catch (Exception e) { return s; }
    }

    private String normalizeUrl(String u) {
        try {
            URI uri = new URI(u);
            String scheme = (uri.getScheme() == null ? "https" : uri.getScheme().toLowerCase(Locale.ROOT));
            String host = (uri.getHost() == null ? "" : uri.getHost().toLowerCase(Locale.ROOT));
            int port = uri.getPort();
            String path = (uri.getPath() == null || uri.getPath().isEmpty()) ? "/" : uri.getPath();
            String query = uri.getQuery();
            StringBuilder sb = new StringBuilder();
            sb.append(scheme).append("://").append(host);
            if (port != -1 && port != uri.toURL().getDefaultPort()) sb.append(":").append(port);
            sb.append(path);
            if (query != null) sb.append("?").append(query);
            return sb.toString();
        } catch (Exception e) { return u; }
    }

    private boolean isSamePage(String candidate, String base) {
        if (candidate == null || base == null) return false;
        try {
            URI a = new URI(candidate), b = new URI(base);
            return a.getHost() != null && b.getHost() != null
                    && a.getHost().equalsIgnoreCase(b.getHost())
                    && ((a.getPath() == null ? "/" : a.getPath())
                    .equals(b.getPath() == null ? "/" : b.getPath()));
        } catch (Exception e) { return candidate.equals(base); }
    }

    private String safeLower(String s) { return (s == null) ? null : s.toLowerCase(Locale.ROOT); }

    private String sha256Hex(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(input.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) { throw new RuntimeException(e); }
    }

    private boolean looksLikeUrl(String s) {
        String t = s.trim().toLowerCase(Locale.ROOT);
        return t.startsWith("http://") || t.startsWith("https://");
    }

    private InputStream boundedStream(HttpURLConnection conn) throws IOException {
        long len = conn.getContentLengthLong();
        if (len > 0 && len > MAX_BYTES) throw new IOException("File too large: " + len);
        return new LimitedInputStream(conn.getInputStream(), MAX_BYTES);
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
            len = (int) Math.min(len, remaining);
            int n = super.read(b, off, len);
            if (n > 0) remaining -= n;
            return n;
        }
    }

    private String readAll(InputStream in) throws IOException {
        return new String(in.readAllBytes(), StandardCharsets.UTF_8);
    }

    private void ensureValidImageBytes(byte[] data) throws IOException {
        if (data == null || data.length < MIN_IMAGE_BYTES) throw new IOException("Image too small");
        if (!looksLikeImage(data)) throw new IOException("Not an image content");
    }

    private static boolean looksLikeImage(byte[] data) {
        if (data == null || data.length < 12) return false;
        if ((data[0] & 0xFF) == 0xFF && (data[1] & 0xFF) == 0xD8 && (data[2] & 0xFF) == 0xFF) return true; // JPEG
        if ((data[0] & 0xFF) == 0x89 && data[1]=='P' && data[2]=='N' && data[3]=='G') return true;         // PNG
        if (data[0]=='G' && data[1]=='I' && data[2]=='F') return true;                                      // GIF
        if (data[0]=='R' && data[1]=='I' && data[2]=='F' && data[3]=='F'
                && data[8]=='W' && data[9]=='E' && data[10]=='B' && data[11]=='P') return true;            // WEBP
        return false;
    }

    private String sniffContentType(byte[] data, String fallback) {
        if (data != null && data.length >= 12) {
            if ((data[0] & 0xFF) == 0xFF && (data[1] & 0xFF) == 0xD8) return "image/jpeg";
            if (data[0]==(byte)0x89 && data[1]=='P' && data[2]=='N' && data[3]=='G') return "image/png";
            if (data[0]=='G' && data[1]=='I' && data[2]=='F') return "image/gif";
            if (data[0]=='R' && data[1]=='I' && data[2]=='F' && data[3]=='F'
                    && data[8]=='W' && data[9]=='E' && data[10]=='B' && data[11]=='P') return "image/webp";
        }
        return (fallback != null) ? fallback : "application/octet-stream";
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
    private static class AssetPair {
        final String imageUrl, thumbnailUrl, videoUrl;
        final LocalDateTime takenAt;
        AssetPair(String i, String t, String v, LocalDateTime ta) { this.imageUrl=i; this.thumbnailUrl=t; this.videoUrl=v; this.takenAt=ta; }
    }
}
