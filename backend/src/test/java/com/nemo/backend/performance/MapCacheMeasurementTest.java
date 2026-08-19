package com.nemo.backend.performance;

import com.nemo.backend.domain.map.controller.PhotoboothController;
import com.nemo.backend.domain.map.service.PhotoboothService;
import com.nemo.backend.domain.map.util.NaverApiClient;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@Tag("map-cache-performance")
class MapCacheMeasurementTest {

    private static final int RUNS = 3;
    private static final int REQUESTS_PER_RUN = 10;
    private static final long CACHE_TTL_MILLIS = 120_000;
    private static final long CACHE_MAXIMUM_SIZE = 1_000;

    private static final AtomicInteger externalCalls = new AtomicInteger();
    private static HttpServer stubServer;
    private static String localEndpoint;

    @BeforeAll
    static void startStubServer() throws IOException {
        stubServer = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        stubServer.createContext("/local.json", MapCacheMeasurementTest::respondWithLocalSearchResult);
        stubServer.start();
        localEndpoint = "http://127.0.0.1:" + stubServer.getAddress().getPort() + "/local.json";
    }

    @AfterAll
    static void stopStubServer() {
        if (stubServer != null) {
            stubServer.stop(0);
        }
    }

    @Test
    void comparesCacheOffAndOnUnderSameRequests() throws Exception {
        measure("WARMUP", 0);

        List<Measurement> offRuns = new ArrayList<>();
        List<Measurement> onRuns = new ArrayList<>();

        for (int run = 1; run <= RUNS; run++) {
            Measurement off = measure("OFF", 0);
            Measurement on = measure("ON", CACHE_TTL_MILLIS);
            offRuns.add(off);
            onRuns.add(on);

            assertThat(off.externalCalls()).isEqualTo(REQUESTS_PER_RUN);
            assertThat(on.externalCalls()).isEqualTo(1);
            assertThat(on.cacheMisses()).isEqualTo(1);
            assertThat(on.cacheHits()).isEqualTo(REQUESTS_PER_RUN - 1);

            printRun(run, off);
            printRun(run, on);
        }

        printSummary("OFF", offRuns);
        printSummary("ON", onRuns);
    }

    private Measurement measure(String mode, long ttlMillis) throws Exception {
        externalCalls.set(0);
        NaverApiClient client = new NaverApiClient(
                new RestTemplate(),
                ttlMillis,
                CACHE_MAXIMUM_SIZE
        );
        ReflectionTestUtils.setField(client, "endpoint", localEndpoint);
        ReflectionTestUtils.setField(client, "clientId", "stub-client-id");
        ReflectionTestUtils.setField(client, "clientSecret", "stub-client-secret");

        MockMvc mockMvc = MockMvcBuilders.standaloneSetup(
                new PhotoboothController(new PhotoboothService(client))
        ).build();

        long started = System.nanoTime();
        for (int request = 0; request < REQUESTS_PER_RUN; request++) {
            mockMvc.perform(get("/api/map/photobooths/search")
                            .param("keyword", "인생네컷")
                            .param("limit", "10"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$[0].name").value("인생네컷 강남점"))
                    .andExpect(jsonPath("$[0].brand").value("인생네컷"))
                    .andExpect(jsonPath("$[0].roadAddress").value("서울 강남구 테헤란로 1"));
        }
        long elapsedNanos = System.nanoTime() - started;

        return new Measurement(
                mode,
                externalCalls.get(),
                elapsedNanos / 1_000_000.0 / REQUESTS_PER_RUN,
                client.cacheStats().hitCount(),
                client.cacheStats().missCount(),
                client.cacheStats().evictionCount()
        );
    }

    private static void respondWithLocalSearchResult(HttpExchange exchange) throws IOException {
        externalCalls.incrementAndGet();
        byte[] body = """
                {"items":[{
                  "title":"<b>인생네컷</b> 강남점",
                  "mapx":"1270000000",
                  "mapy":"375000000",
                  "roadAddress":"서울 강남구 테헤란로 1",
                  "link":"https://example.test/place/1"
                }]}
                """.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=UTF-8");
        exchange.sendResponseHeaders(200, body.length);
        try (OutputStream output = exchange.getResponseBody()) {
            output.write(body);
        }
    }

    private void printRun(int run, Measurement measurement) {
        System.out.printf(
                Locale.ROOT,
                "MAP_CACHE_MEASUREMENT run=%d mode=%s requests=%d external_calls=%d "
                        + "avg_response_ms=%.3f cache_hits=%d cache_misses=%d cache_evictions=%d%n",
                run,
                measurement.mode(),
                REQUESTS_PER_RUN,
                measurement.externalCalls(),
                measurement.averageResponseMillis(),
                measurement.cacheHits(),
                measurement.cacheMisses(),
                measurement.cacheEvictions()
        );
    }

    private void printSummary(String mode, List<Measurement> runs) {
        double averageMillis = runs.stream()
                .mapToDouble(Measurement::averageResponseMillis)
                .average()
                .orElseThrow();
        double averageExternalCalls = runs.stream()
                .mapToInt(Measurement::externalCalls)
                .average()
                .orElseThrow();
        System.out.printf(
                Locale.ROOT,
                "MAP_CACHE_MEASUREMENT_SUMMARY mode=%s runs=%d requests_per_run=%d "
                        + "avg_external_calls=%.1f avg_response_ms=%.3f%n",
                mode,
                runs.size(),
                REQUESTS_PER_RUN,
                averageExternalCalls,
                averageMillis
        );
    }

    private record Measurement(
            String mode,
            int externalCalls,
            double averageResponseMillis,
            long cacheHits,
            long cacheMisses,
            long cacheEvictions
    ) {
    }
}
