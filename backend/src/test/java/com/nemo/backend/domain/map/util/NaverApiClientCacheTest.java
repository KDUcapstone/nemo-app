package com.nemo.backend.domain.map.util;

import com.github.benmanes.caffeine.cache.Ticker;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.RestTemplate;

import java.net.URI;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class NaverApiClientCacheTest {

    @Test
    void sameRequestUsesCachedResponseAndRecordsHit() {
        RestTemplate restTemplate = mock(RestTemplate.class);
        NaverApiClient client = client(restTemplate, 120_000, 1_000, new MutableTicker());
        Map<String, Object> response = localResponse("인생네컷 강남점");
        stubResponse(restTemplate, response);

        Map<String, Object> first = client.searchLocal("인생네컷", 5, 1, "random");
        Map<String, Object> second = client.searchLocal("인생네컷", 5, 1, "random");

        assertThat(first).isEqualTo(response);
        assertThat(second).isEqualTo(response);
        verify(restTemplate, times(1))
                .exchange(any(URI.class), eq(HttpMethod.GET), any(HttpEntity.class), eq(Map.class));
        assertThat(client.cacheStats().missCount()).isEqualTo(1);
        assertThat(client.cacheStats().hitCount()).isEqualTo(1);
    }

    @Test
    void sameReverseGeocodeRequestUsesSharedCachePolicy() {
        RestTemplate restTemplate = mock(RestTemplate.class);
        NaverApiClient client = client(restTemplate, 120_000, 1_000, new MutableTicker());
        Map<String, Object> response = Map.of("results", List.of(Map.of(
                "region", Map.of(
                        "area2", Map.of("name", "강남구"),
                        "area3", Map.of("name", "역삼동")
                )
        )));
        stubResponse(restTemplate, response);

        assertThat(client.reverseGeocodeToRegion(37.5, 127.0)).contains("강남구 역삼동");
        assertThat(client.reverseGeocodeToRegion(37.5, 127.0)).contains("강남구 역삼동");

        verify(restTemplate, times(1))
                .exchange(any(URI.class), eq(HttpMethod.GET), any(HttpEntity.class), eq(Map.class));
        assertThat(client.cacheStats().missCount()).isEqualTo(1);
        assertThat(client.cacheStats().hitCount()).isEqualTo(1);
    }

    @Test
    void expiredRequestCallsExternalApiAgain() {
        RestTemplate restTemplate = mock(RestTemplate.class);
        MutableTicker ticker = new MutableTicker();
        NaverApiClient client = client(restTemplate, 1_000, 1_000, ticker);
        stubResponse(restTemplate, localResponse("인생네컷 강남점"));

        client.searchLocal("인생네컷", 5, 1, "random");
        ticker.advance(Duration.ofMillis(1_001));
        client.searchLocal("인생네컷", 5, 1, "random");

        verify(restTemplate, times(2))
                .exchange(any(URI.class), eq(HttpMethod.GET), any(HttpEntity.class), eq(Map.class));
        assertThat(client.cacheStats().missCount()).isEqualTo(2);
        assertThat(client.cacheStats().hitCount()).isZero();
    }

    @Test
    void zeroTtlDisablesCache() {
        RestTemplate restTemplate = mock(RestTemplate.class);
        NaverApiClient client = client(restTemplate, 0, 1_000, new MutableTicker());
        stubResponse(restTemplate, localResponse("인생네컷 강남점"));

        client.searchLocal("인생네컷", 5, 1, "random");
        client.searchLocal("인생네컷", 5, 1, "random");

        verify(restTemplate, times(2))
                .exchange(any(URI.class), eq(HttpMethod.GET), any(HttpEntity.class), eq(Map.class));
        assertThat(client.cacheStats().requestCount()).isZero();
        assertThat(client.cacheEstimatedSize()).isZero();
    }

    @Test
    void entriesOverMaximumSizeAreEvicted() {
        RestTemplate restTemplate = mock(RestTemplate.class);
        NaverApiClient client = client(restTemplate, 120_000, 1, new MutableTicker());
        stubResponse(restTemplate, localResponse("포토부스"));

        client.searchLocal("인생네컷", 5, 1, "random");
        client.searchLocal("포토이즘", 5, 1, "random");

        assertThat(client.cacheEstimatedSize()).isLessThanOrEqualTo(1);
        assertThat(client.cacheStats().evictionCount()).isEqualTo(1);
    }

    private NaverApiClient client(
            RestTemplate restTemplate,
            long ttlMillis,
            long maximumSize,
            Ticker ticker
    ) {
        NaverApiClient client = new NaverApiClient(restTemplate, ttlMillis, maximumSize, ticker);
        ReflectionTestUtils.setField(client, "endpoint", "https://stub.test/local.json");
        ReflectionTestUtils.setField(client, "clientId", "test-client-id");
        ReflectionTestUtils.setField(client, "clientSecret", "test-client-secret");
        ReflectionTestUtils.setField(client, "reverseEndpoint", "https://stub.test/reverse");
        ReflectionTestUtils.setField(client, "mapClientId", "test-map-client-id");
        ReflectionTestUtils.setField(client, "mapClientSecret", "test-map-client-secret");
        return client;
    }

    @SuppressWarnings({"rawtypes", "unchecked"})
    private void stubResponse(RestTemplate restTemplate, Map<String, Object> response) {
        when(restTemplate.exchange(
                any(URI.class),
                eq(HttpMethod.GET),
                any(HttpEntity.class),
                eq(Map.class)
        )).thenReturn(ResponseEntity.ok(response));
    }

    private Map<String, Object> localResponse(String title) {
        return Map.of("items", List.of(Map.of(
                "title", title,
                "mapx", "1270000000",
                "mapy", "375000000"
        )));
    }

    private static final class MutableTicker implements Ticker {
        private final AtomicLong nanos = new AtomicLong();

        @Override
        public long read() {
            return nanos.get();
        }

        void advance(Duration duration) {
            nanos.addAndGet(duration.toNanos());
        }
    }
}
