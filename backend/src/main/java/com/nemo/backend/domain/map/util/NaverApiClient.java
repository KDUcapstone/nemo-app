// src/main/java/com/nemo/backend/domain/map/util/NaverApiClient.java
package com.nemo.backend.domain.map.util;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

@Slf4j
@Component
@RequiredArgsConstructor
public class NaverApiClient {

    // ✔ application.yml 에서 값을 주입
    @Value("${naver.openapi.local.endpoint:https://openapi.naver.com/v1/search/local.json}")
    private String endpoint;

    @Value("${NAVER_LOCAL_CLIENT_ID}")
    private String clientId;

    @Value("${NAVER_LOCAL_CLIENT_SECRET}")
    private String clientSecret;

    private final RestTemplate restTemplate;

    // ───────────────────────────────────────────────────────────────
    // (A) 간단 캐시: 같은 요청(같은 뷰포트/키워드)은 2분간 재사용
    // key: 완성된 URI 문자열, value: 캐시 항목(응답+저장시각)
    private static final long CACHE_TTL_MILLIS = Duration.ofMinutes(2).toMillis();
    private final ConcurrentHashMap<String, CacheEntry> cache = new ConcurrentHashMap<>();

    private record CacheEntry(Map<String, Object> body, long savedAtMs) {}
    // ───────────────────────────────────────────────────────────────

    // ───────────────────────────────────────────────────────────────
    // (B) 아주 단순한 레이트 리미터: 외부 호출 사이 최소 간격 200ms 확보(초당 최대 5회)
    private static final long MIN_INTERVAL_MS = 200;
    private final AtomicLong lastCallAt = new AtomicLong(0);
    // ───────────────────────────────────────────────────────────────

    /**
     * 지역검색(Local Search) 1회 호출
     *
     * @param query   검색어 (예: "포토부스", "인생네컷")
     * @param display 한 번에 가져올 개수 (문서 기준 1~5)
     * @param start   시작 위치(1~1000) — 페이지네이션
     * @param sort    정렬("random"(정확도, 기본) / "comment"(리뷰 많은 순))
     * @return        네이버 JSON을 Map으로 그대로 반환(가공은 Service에서)
     */
    public Map<String, Object> searchLocal(String query, int display, int start, String sort) {

        // 0) 입력값 안전장치 (문서 범위에 맞게)
        if (query == null || query.isBlank()) {
            throw new IllegalArgumentException("query는 비어있을 수 없어요.");
        }
        int safeDisplay = clamp(display, 1, 5);         // 문서 이미지 기준: 최대 5
        int safeStart   = clamp(start,   1, 1000);
        String safeSort = ("comment".equalsIgnoreCase(sort)) ? "comment" : "random";

        // 1) 요청 URL (한글은 UTF-8 인코딩 필수)
        URI uri = UriComponentsBuilder.fromHttpUrl(endpoint)
                .queryParam("query", query)
                .queryParam("display", safeDisplay)
                .queryParam("start", safeStart)
                .queryParam("sort", safeSort)
                .encode(StandardCharsets.UTF_8)
                .build()
                .toUri();

        String cacheKey = uri.toString();

        // 2) 캐시 확인 (2분 내면 재사용)
        Map<String, Object> cached = loadFromCache(cacheKey);
        if (cached != null) {
            log.debug("[NAVER][CACHE-HIT] {}", cacheKey);
            return cached;
        }

        // 3) 헤더 (네이버 개발자 센터 방식)
        HttpHeaders headers = new HttpHeaders();
        headers.set("X-Naver-Client-Id", clientId);
        headers.set("X-Naver-Client-Secret", clientSecret);

        // 4) 레이트 리밋: 외부로 너무 자주 나가지 않도록 최소 간격 보장
        enforceMinInterval();

        // 5) 429(Too Many Requests) 대비: 최대 3회 재시도 (백오프 + Retry-After 존중)
        int maxAttempts = 3;                // 최초 + 재시도 2회
        long baseBackoffMs = 500;           // 0.5s → 1.0s → (최대) 2.0s
        HttpEntity<Void> httpEntity = new HttpEntity<>(headers);

        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                ResponseEntity<Map> res = restTemplate.exchange(uri, HttpMethod.GET, httpEntity, Map.class);
                Map<String, Object> body = res.getBody();

                // 6) 성공: 캐시에 저장 후 반환
                saveToCache(cacheKey, body);
                return body;

            } catch (HttpClientErrorException.TooManyRequests e) {
                // 429면 '잠깐 쉬었다 와'라는 뜻
                int finalAttempt = attempt;
                long waitMs = parseRetryAfterToMillis(e.getResponseHeaders()).orElseGet(
                        () -> (long) (baseBackoffMs * Math.pow(2, finalAttempt - 1)) // 500 → 1000 → 2000
                );
                log.warn("[NAVER][429] attempt {} / {} → {}ms 대기 후 재시도. uri={}",
                        attempt, maxAttempts, waitMs, cacheKey);

                sleepSilently(waitMs);

                // 다음 루프에서 자동 재시도
                if (attempt == maxAttempts) {
                    // 그래도 안 되면, UX 위해 '빈 결과'라도 내려주거나, 예외를 올려 컨트롤러에서 503으로 변환
                    throw e; // 전역 예외 핸들러에서 503(Service Unavailable) 매핑 권장
                }

            } catch (HttpClientErrorException e) {
                // 잘못된 파라미터 등 4xx — 재시도해도 소용없으니 바로 rethrow
                log.error("[NAVER][4xx] status={} body={} uri={}",
                        e.getStatusCode(), safe(e.getResponseBodyAsString()), cacheKey);
                throw e;

            } catch (Exception e) {
                // 네트워크 등 일시 오류 → 백오프로 짧게 재시도
                long waitMs = (long) (baseBackoffMs * Math.pow(2, attempt - 1));
                log.warn("[NAVER][EX] attempt {} / {} → {}ms 대기 후 재시도. uri={} ex={}",
                        attempt, maxAttempts, waitMs, cacheKey, e.toString());
                if (attempt == maxAttempts) throw new RuntimeException("Naver Local API 호출 실패", e);
                sleepSilently(waitMs);
            }
        }

        // 여긴 도달하지 않음
        throw new IllegalStateException("도달 불가");
    }

    // ─────────────────────── helpers ─────────────────────────

    private static int clamp(int v, int min, int max) {
        return Math.max(min, Math.min(max, v));
    }

    private Map<String, Object> loadFromCache(String key) {
        CacheEntry entry = cache.get(key);
        if (entry == null) return null;
        long age = System.currentTimeMillis() - entry.savedAtMs();
        if (age <= CACHE_TTL_MILLIS) return entry.body();
        cache.remove(key); // 만료되면 정리
        return null;
    }

    private void saveToCache(String key, Map<String, Object> body) {
        cache.put(key, new CacheEntry(Objects.requireNonNullElse(body, Map.of()), System.currentTimeMillis()));
    }

    // 외부 호출 최소 간격 보장 (아주 단순한 방식)
    private void enforceMinInterval() {
        long now = System.currentTimeMillis();
        long last = lastCallAt.get();
        long elapsed = now - last;
        if (elapsed < MIN_INTERVAL_MS) {
            sleepSilently(MIN_INTERVAL_MS - elapsed);
        }
        lastCallAt.set(System.currentTimeMillis());
    }

    private static Optional<Long> parseRetryAfterToMillis(HttpHeaders headers) {
        if (headers == null) return Optional.empty();
        String raw = headers.getFirst("Retry-After");
        if (raw == null) return Optional.empty();
        try {
            // 네이버가 초(second)로 준다고 가정
            long seconds = Long.parseLong(raw.trim());
            return Optional.of(Duration.ofSeconds(seconds).toMillis());
        } catch (NumberFormatException ignored) {
            return Optional.empty();
        }
    }

    private static void sleepSilently(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
        }
    }

    private static String safe(String s) {
        return s == null ? "" : s.substring(0, Math.min(500, s.length()));
    }
}
