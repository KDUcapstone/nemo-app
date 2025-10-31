package com.nemo.backend.domain.photo.service;

import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.domain.photo.repository.PhotoRepository;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;
import org.springframework.beans.factory.annotation.Autowired;
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
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
@Transactional
public class PhotoServiceImpl implements PhotoService {

    private static final int CONNECT_TIMEOUT_MS = 5000;
    private static final int READ_TIMEOUT_MS    = 10000;
    private static final int MAX_REDIRECTS      = 5;
    private static final int MAX_HTML_FOLLOW    = 2;
    private static final long MAX_BYTES         = 50L * 1024 * 1024; // 이미지/영상 공통 업로드 제한
    private static final String USER_AGENT      = "nemo-app/1.0 (+https://nemo)";
    private static final String[] ALLOWED_SCHEMES = {"http", "https"};

    private final PhotoRepository photoRepository;
    private final PhotoStorage storage;
    private final QrDecoder qrDecoder;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Autowired
    public PhotoServiceImpl(PhotoRepository photoRepository,
                            PhotoStorage storage,
                            QrDecoder qrDecoder) {
        this.photoRepository = photoRepository;
        this.storage = storage;
        this.qrDecoder = qrDecoder;
    }

    @Override
    public PhotoResponseDto upload(Long userId, MultipartFile qrFile) {
        if (qrFile == null || qrFile.isEmpty()) throw new IllegalArgumentException("QR 파일이 없습니다.");

        // 1) QR 디코드
        String payload = qrDecoder.decode(qrFile);
        if (payload == null || payload.isBlank()) throw new InvalidQrException("QR 코드를 해석할 수 없습니다.");

        // 2) 만료값(숫자) 방어: 과거면 Expired → 404
        if (payload.chars().allMatch(Character::isDigit)) {
            try {
                long expiryMillis = Long.parseLong(payload.trim());
                if (System.currentTimeMillis() > expiryMillis) {
                    throw new ExpiredQrException("만료된 QR 코드입니다.");
                }
            } catch (NumberFormatException e) {
                throw new InvalidQrException("유효하지 않은 QR 만료값입니다.", e);
            }
        }

        // 3) 중복 방지 해시
        String qrHash = sha256Hex(payload);
        photoRepository.findByQrHash(qrHash).ifPresent(p -> { throw new DuplicateQrException("이미 업로드된 QR입니다."); });

        // 4) 자산 수집
        AssetPair assets;
        try {
            if (looksLikeUrl(payload)) {
                assets = fetchAssetsFromQrPayload(payload);
            } else {
                assets = storeFromNonUrlPayload(payload);
            }
        } catch (ExpiredQrException | InvalidQrException e) {
            throw e; // 그대로 전달 (404/400)
        } catch (IOException e) {
            // 네트워크/접근 제한 등은 만료로 간주(404)
            throw new ExpiredQrException("QR 자원을 가져오는 데 실패했습니다.", e);
        }

        // 브랜드 추출(간단 키워드)
        String brand = inferBrand(payload);

        // 5) 저장
        Photo photo = new Photo(
                userId,
                null,
                assets.imageUrl,
                assets.thumbnailUrl,
                assets.videoUrl,
                qrHash,
                brand,
                assets.takenAt,
                null
        );
        Photo saved = photoRepository.save(photo);
        return new PhotoResponseDto(saved);
    }

    // ===================== 자산 수집 =====================

    /**
     * life4cut, 하루필름 등 도메인을 우선 체크하여 특수 처리한 뒤,
     * 나머지는 기존 HTML/리다이렉트 추적 로직으로 처리.
     */
    private AssetPair fetchAssetsFromQrPayload(String startUrl) throws IOException {
        // 특정 포토부스 API는 JSON을 반환하므로 우선 처리
        if (startUrl.contains("api.life4cut.net")) {
            return fetchLife4cutAssets(startUrl);
        }
        if (startUrl.contains("harufilm.kr/api/qrcode.php")) {
            return fetchHaruFilmAssets(startUrl);
        }

        CookieManager cm = new CookieManager(null, CookiePolicy.ACCEPT_ALL);
        CookieHandler.setDefault(cm);

        String current = startUrl;
        int htmlFollow = 0;

        String foundImage = null;
        String foundVideo = null;
        String foundThumb = null;

        for (int redirects = 0; redirects <= MAX_REDIRECTS; redirects++) {
            URL url = new URL(current);
            if (!isAllowedScheme(url)) throw new IOException("Unsupported URL scheme: " + url.getProtocol());

            HttpURLConnection conn = open(current, "GET", null, startUrl);
            int code = conn.getResponseCode();

            // 수동 리다이렉트
            if (code / 100 == 3) {
                String location = conn.getHeaderField("Location");
                if (location == null || location.isBlank()) throw new IOException("Redirect without Location");
                current = new URL(url, location).toString();
                continue;
            }

            String contentType = safeLower(conn.getContentType());

            // 파일 스트림 응답 (이미지/영상/첨부)
            String cd = conn.getHeaderField("Content-Disposition");
            boolean isAttachment = cd != null && cd.toLowerCase(Locale.ROOT).contains("attachment");
            if ((contentType != null && (contentType.startsWith("image/") || contentType.startsWith("video/"))) || isAttachment) {
                try (InputStream in = boundedStream(conn)) {
                    String ct = (contentType != null) ? contentType : "application/octet-stream";
                    String ext = extractExtensionFromContentType(ct);
                    MultipartFile mf = toMultipart(in, ct, ext);
                    String stored = storage.store(mf);

                    if (ct.startsWith("image/")) {
                        if (foundImage == null) foundImage = stored;
                        if (foundThumb == null)  foundThumb  = stored; // 썸네일 없으면 이미지로 대체
                    } else if (ct.startsWith("video/")) {
                        if (foundVideo == null) foundVideo = stored;
                    }
                }
                break; // 파일 응답이면 종료
            }

            // HTML 파싱
            if (contentType != null && contentType.startsWith("text/html")) {
                if (htmlFollow >= MAX_HTML_FOLLOW) break;
                String html = readAll(conn.getInputStream());
                // 1) 메타/태그 기반 추출
                HtmlExtracted he = extractFromHtml(html, current);
                if (he.imageUrl != null && foundImage == null) foundImage = downloadToStorage(he.imageUrl, startUrl);
                if (he.thumbnailUrl != null && foundThumb == null) foundThumb = downloadToStorage(he.thumbnailUrl, startUrl);
                if (he.videoUrl != null && foundVideo == null) foundVideo = downloadToStorage(he.videoUrl, startUrl);

                // 2) 폼 기반 다운로드 흐름 (필요 시)
                if ((foundImage == null || foundVideo == null) && he.postForm != null) {
                    String actionAbs = new URL(url, he.postForm.action != null ? he.postForm.action : current).toString();
                    String body = he.postForm.encode();
                    HttpURLConnection post = open(actionAbs, "POST", body, current);
                    String ct2 = safeLower(post.getContentType());
                    String cd2 = post.getHeaderField("Content-Disposition");
                    boolean attach2 = cd2 != null && cd2.toLowerCase(Locale.ROOT).contains("attachment");

                    if (ct2 != null && (ct2.startsWith("image/") || ct2.startsWith("video/")) || attach2) {
                        try (InputStream in = boundedStream(post)) {
                            String realCt = (ct2 != null) ? ct2 : "application/octet-stream";
                            String ext = extractExtensionFromContentType(realCt);
                            MultipartFile mf = toMultipart(in, realCt, ext);
                            String stored = storage.store(mf);
                            if (realCt.startsWith("image/")) {
                                if (foundImage == null) foundImage = stored;
                                if (foundThumb == null)  foundThumb  = stored;
                            } else if (realCt.startsWith("video/")) {
                                if (foundVideo == null) foundVideo = stored;
                            }
                        }
                    } else {
                        // POST 결과가 다시 HTML이면 추가 파싱
                        String html2 = readAll(post.getInputStream());
                        HtmlExtracted he2 = extractFromHtml(html2, actionAbs);
                        if (he2.imageUrl != null && foundImage == null) foundImage = downloadToStorage(he2.imageUrl, startUrl);
                        if (he2.thumbnailUrl != null && foundThumb == null) foundThumb = downloadToStorage(he2.thumbnailUrl, startUrl);
                        if (he2.videoUrl != null && foundVideo == null) foundVideo = downloadToStorage(he2.videoUrl, startUrl);
                    }
                }

                // 다음 후보 링크가 있으면 한번 더 따라가기
                if (he.nextGetUrl != null) {
                    current = new URL(url, he.nextGetUrl).toString();
                    htmlFollow++;
                    continue;
                }
                break;
            }

            // 그 외 콘텐츠 타입은 포기
            break;
        }

        if (foundImage == null && foundVideo == null) {
            throw new IOException("이미지/영상 URL을 찾지 못했습니다.");
        }
        // 썸네일 없으면 이미지로 대체
        if (foundThumb == null) foundThumb = foundImage;

        return new AssetPair(foundImage, foundThumb, foundVideo, /*takenAt*/ null);
    }

    /**
     * Life4cut 전용 JSON/텍스트 응답 처리.
     * 이미지와 비디오를 찾지 못하면 예외를 던진다.
     */
    private AssetPair fetchLife4cutAssets(String url) throws IOException {
        HttpURLConnection conn = open(url, "GET", null, url);
        String body = readAll(conn.getInputStream());

        // 정규식으로 이미지/비디오 URL 추출
        List<String> images = new ArrayList<>();
        Matcher mImg = Pattern.compile("(https?://[^\\s\"']+\\.(?:png|jpe?g|gif|webp))",
                Pattern.CASE_INSENSITIVE).matcher(body);
        while (mImg.find()) {
            images.add(mImg.group(1));
        }
        String video = null;
        Matcher mVid = Pattern.compile("(https?://[^\\s\"']+\\.(?:mp4|mov|webm|m4v))",
                Pattern.CASE_INSENSITIVE).matcher(body);
        if (mVid.find()) video = mVid.group(1);

        String storedImg = null;
        String thumb = null;
        if (!images.isEmpty()) {
            storedImg = downloadToStorage(images.get(0), url);
            thumb = storedImg;
        }
        String storedVideo = null;
        if (video != null) {
            storedVideo = downloadToStorage(video, url);
        }

        if (storedImg == null && storedVideo == null) {
            throw new IOException("Life4cut 응답에서 이미지나 비디오를 찾지 못했습니다.");
        }
        return new AssetPair(storedImg, thumb, storedVideo, null);
    }

    /**
     * 하루필름 전용 JSON 응답 처리.
     * 키명을 알 수 없는 경우 life4cut 방식으로 fallback.
     */
    private AssetPair fetchHaruFilmAssets(String url) throws IOException {
        HttpURLConnection conn = open(url, "GET", null, url);
        String body = readAll(conn.getInputStream());
        try {
            JsonNode root = objectMapper.readTree(body);
            List<String> imgs = new ArrayList<>();
            if (root.has("imageUrls")) {
                root.get("imageUrls").forEach(node -> imgs.add(node.asText()));
            } else if (root.has("img_list")) {
                root.get("img_list").forEach(node -> imgs.add(node.asText()));
            }
            String video = null;
            if (root.has("videoUrl")) {
                video = root.get("videoUrl").asText();
            } else if (root.has("video")) {
                video = root.get("video").asText();
            }

            String storedImg = null;
            String thumb = null;
            if (!imgs.isEmpty()) {
                storedImg = downloadToStorage(imgs.get(0), url);
                thumb = storedImg;
            }
            String storedVideo = null;
            if (video != null && !video.isBlank()) {
                storedVideo = downloadToStorage(video, url);
            }

            if (storedImg == null && storedVideo == null) {
                throw new IOException("HaruFilm 응답에서 이미지나 비디오를 찾지 못했습니다.");
            }
            return new AssetPair(storedImg, thumb, storedVideo, null);
        } catch (Exception ex) {
            // JSON 파싱 실패 시 life4cut 방식으로 대체
            return fetchLife4cutAssets(url);
        }
    }

    private AssetPair storeFromNonUrlPayload(String payload) throws IOException {
        // URL이 아닌 QR 포맷(예: base64, 커스텀 프로토콜 등)을 다루려면 여기 구현
        throw new InvalidQrException("지원하지 않는 QR 포맷입니다.");
    }

    // ===================== HTML 파서 =====================

    private HtmlExtracted extractFromHtml(String html, String baseUrl) {
        Document doc = Jsoup.parse(html, baseUrl);

        HtmlExtracted out = new HtmlExtracted();

        out.imageUrl = firstMeta(doc,
                "meta[property=og:image]", "meta[name=og:image]",
                "meta[property=og:image:url]", "meta[property=og:image:secure_url]",
                "meta[name=twitter:image]", "meta[name=twitter:image:src]",
                "meta[itemprop=image]"
        );
        out.thumbnailUrl = firstMeta(doc,
                "meta[property=og:image:thumbnail]", "meta[name=thumbnail]"
        );

        out.videoUrl = firstMeta(doc,
                "meta[property=og:video]", "meta[name=og:video]",
                "meta[property=og:video:url]", "meta[property=og:video:secure_url]",
                "meta[name=twitter:player]"
        );

        // 다운로드 링크/버튼에서 image/video 키워드 추출
        Elements links = doc.select("a[download], a#download, a.button, a, button, .btn, .button");
        for (Element el : links) {
            String text = (el.hasText() ? el.text() : "").toLowerCase(Locale.ROOT);
            String href = el.attr("href");
            String dataHref = el.attr("data-href");
            String dataUrl  = el.attr("data-url");
            String candidate = firstNonBlank(href, dataHref, dataUrl);

            if (candidate == null || candidate.isBlank()) continue;

            boolean looksImage = text.contains("image") || text.contains("이미지");
            boolean looksVideo = text.contains("video") || text.contains("동영상");

            if (looksImage && out.imageUrl == null) out.imageUrl = candidate;
            if (looksVideo && out.videoUrl == null) out.videoUrl = candidate;
            if (out.nextGetUrl == null) out.nextGetUrl = candidate; // 다음 단계 후보
        }

        // <video src> / <source src> 탐색 (직접 링크)
        if (out.videoUrl == null) {
            Element v = doc.selectFirst("video[src], video source[src]");
            if (v != null) out.videoUrl = v.hasAttr("src") ? v.attr("src") : null;
        }

        // 마지막 fallback: 첫 번째 img
        if (out.imageUrl == null) {
            Element img = doc.selectFirst("img[src]");
            if (img != null) out.imageUrl = img.attr("src");
        }

        // script 안의 정규식으로 jpg/mp4 스캔
        for (Element s : doc.select("script")) {
            String code = s.data();
            if (out.imageUrl == null) {
                Matcher m1 = Pattern.compile("(https?://[^\\s\"'>)]+\\.(?:png|jpe?g|gif|webp))",
                        Pattern.CASE_INSENSITIVE).matcher(code);
                if (m1.find()) out.imageUrl = m1.group(1);
            }
            if (out.videoUrl == null) {
                Matcher m2 = Pattern.compile("(https?://[^\\s\"'>)]+\\.(?:mp4|mov|webm|m4v))",
                        Pattern.CASE_INSENSITIVE).matcher(code);
                if (m2.find()) out.videoUrl = m2.group(1);
            }
        }

        // meta refresh
        if (out.nextGetUrl == null) {
            Element refresh = doc.selectFirst("meta[http-equiv=refresh][content]");
            if (refresh != null) {
                String content = refresh.attr("content"); // "0;url=/path"
                int p = content.toLowerCase(Locale.ROOT).indexOf("url=");
                if (p >= 0) out.nextGetUrl = content.substring(p + 4).trim();
            }
        }

        return out;
    }

    // ===================== 네트워크/저장 공통 =====================

    private String downloadToStorage(String absOrRelUrl, String referer) throws IOException {
        URL abs = new URL(new URL(referer), absOrRelUrl);
        HttpURLConnection conn = open(abs.toString(), "GET", null, referer);
        String contentType = safeLower(conn.getContentType());
        try (InputStream in = boundedStream(conn)) {
            String ct = contentType != null ? contentType : "application/octet-stream";
            String ext = extractExtensionFromContentType(ct);
            MultipartFile mf = toMultipart(in, ct, ext);
            return storage.store(mf);
        }
    }

    private HttpURLConnection open(String url, String method, String body, String referer) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setInstanceFollowRedirects(false);
        conn.setConnectTimeout(CONNECT_TIMEOUT_MS);
        conn.setReadTimeout(READ_TIMEOUT_MS);
        conn.setRequestProperty("User-Agent", USER_AGENT);
        conn.setRequestProperty("Accept",
                "text/html,application/xhtml+xml,application/xml," +
                        "image/avif,image/webp,image/*;q=0.9,video/*;q=0.9,*/*;q=0.8");
        conn.setRequestProperty("Accept-Language", "ko,ko-KR;q=0.9,en-US;q=0.8,en;q=0.7");
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
        // 여기서 바로 상태코드 판독
        int code = conn.getResponseCode();
        if (code == 400) {
            throw new InvalidQrException("원격 서버가 요청을 거부했습니다. (400)");
        }
        if (code == 404 || code == 410) {
            throw new ExpiredQrException("원격 자원이 존재하지 않습니다. (HTTP " + code + ")");
        }
        return conn;
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

    private boolean looksLikeUrl(String s) {
        String t = s.trim().toLowerCase(Locale.ROOT);
        return t.startsWith("http://") || t.startsWith("https://");
    }

    private boolean isAllowedScheme(URL url) {
        String p = url.getProtocol().toLowerCase(Locale.ROOT);
        for (String s : ALLOWED_SCHEMES) if (p.equals(s)) return true;
        return false;
    }

    private String safeLower(String s) { return (s == null) ? null : s.toLowerCase(Locale.ROOT); }

    private String sha256Hex(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(input.getBytes()));
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException(e);
        }
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

    private static String firstNonBlank(String... v) {
        for (String s : v) if (s != null && !s.isBlank()) return s;
        return null;
    }

    private String inferBrand(String urlOrPayload) {
        String s = urlOrPayload.toLowerCase(Locale.ROOT);
        if (s.contains("인생네컷") || s.contains("life4cut")) return "인생네컷";
        if (s.contains("하루필름") || s.contains("harufilm")) return "하루필름";
        if (s.contains("photogray") || s.contains("pgshort")) return "포토그레이";
        if (s.contains("exit") || s.contains("photoqr3")) return "엑시트";
        if (s.contains("photoism")) return "포토이즘";
        if (s.contains("signature")) return "포토시그니쳐";
        if (s.contains("howdyoudo") || s.contains("하우두유두")) return "하우두유두";
        if (s.contains("twin") || s.contains("트윈")) return "트윈포토";
        return null;
    }

    // ======= 내부 타입/헬퍼 =======

    private static class AssetPair {
        final String imageUrl;
        final String thumbnailUrl;
        final String videoUrl;
        final LocalDateTime takenAt;
        AssetPair(String i, String t, String v, LocalDateTime ta) {
            this.imageUrl = i; this.thumbnailUrl = t; this.videoUrl = v; this.takenAt = ta;
        }
    }

    private static class HtmlExtracted {
        String imageUrl;
        String thumbnailUrl;
        String videoUrl;
        String nextGetUrl;
        PostForm postForm;
    }

    private static class PostForm {
        String action;
        Map<String, String> fields = new LinkedHashMap<>();
        String encode() {
            return fields.entrySet().stream()
                    .map(e -> enc(e.getKey()) + "=" + enc(e.getValue()))
                    .collect(Collectors.joining("&"));
        }
        private static String enc(String s) {
            try { return URLEncoder.encode(s, StandardCharsets.UTF_8); }
            catch (Exception e) { return ""; }
        }
    }

    private static class LimitedInputStream extends java.io.FilterInputStream {
        private long remaining;
        protected LimitedInputStream(InputStream in, long maxBytes) {
            super(in); this.remaining = maxBytes;
        }
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

    /**
     * InputStream 전체를 문자열로 읽어오는 헬퍼 메서드.
     * 기존 코드에 없어서 추가.
     */
    private String readAll(InputStream in) throws IOException {
        StringBuilder sb = new StringBuilder();
        try (InputStream is = in) {
            byte[] buffer = new byte[8192];
            int n;
            while ((n = is.read(buffer)) != -1) {
                sb.append(new String(buffer, 0, n, StandardCharsets.UTF_8));
            }
        }
        return sb.toString();
    }

    // 목록/삭제 (기존과 동일)
    @Override @Transactional(readOnly = true)
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
}
