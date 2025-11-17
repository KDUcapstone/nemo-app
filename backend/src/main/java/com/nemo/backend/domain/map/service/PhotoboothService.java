// src/main/java/com/nemo/backend/domain/map/service/PhotoboothService.java
package com.nemo.backend.domain.map.service;

import com.nemo.backend.domain.map.dto.PhotoboothDto;
import com.nemo.backend.domain.map.dto.ViewportRequest;
import com.nemo.backend.domain.map.util.NaverApiClient;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PhotoboothService {

    private final NaverApiClient naverApiClient;

    // ✅ 검색 키워드(브랜드 + 일반 키워드)
    private static final List<String> KEYWORDS = List.of(
            "포토부스", "인생네컷", "하루필름", "포토이즘", "포토시그널", "포토그레이", "돈룩업"
    );

    // ✅ 네이버 Local API 제약: display 최대 5
    private static final int PAGE_SIZE = 5;

    // ✅ 한 키워드당 최대 페이지 수(너무 많이 긁지 않도록 안전 장치)
    //   → 4면 최대 20개(5×4), 필요 시 늘리되 429 위험 고려
    private static final int MAX_PAGES_PER_KEYWORD = 4;

    /**
     * 뷰포트(현재 지도 화면) 안에 있는 포토부스들 반환
     */
    public List<PhotoboothDto> getPhotoboothsInViewport(ViewportRequest req) {

        // 1) 키워드별로 '페이지네이션' 하며 안전하게 수집
        List<Map<String, Object>> raw = new ArrayList<>();

        for (String kw : KEYWORDS) {
            int page = 0;
            boolean hasMore = true;

            while (hasMore && page < MAX_PAGES_PER_KEYWORD) {
                page++;
                // start는 1부터 시작, display=5이면 1,6,11,... 식으로 넘김
                int start = 1 + (page - 1) * PAGE_SIZE;

                Map<String, Object> res = naverApiClient.searchLocal(kw, PAGE_SIZE, start, "random");
                List<Map<String, Object>> items = extractItems(res);

                // 아이템 없으면 이 키워드는 더 이상 호출 안 함
                if (items.isEmpty()) {
                    hasMore = false;
                } else {
                    raw.addAll(items);
                    // 마지막 페이지(5개 미만 반환)면 다음부터는 중단
                    if (items.size() < PAGE_SIZE) hasMore = false;
                }
            }
        }

        // 2) map → PhotoboothDto (좌표 변환/브랜드 추정/이름 클린업)
        List<PhotoboothDto> all = raw.stream()
                .map(this::toDto)
                .filter(dto -> dto.getLatitude() != 0 && dto.getLongitude() != 0) // 좌표 없는건 제외
                .collect(Collectors.toList());

        // 3) 뷰포트 안에 있는 것만
        List<PhotoboothDto> filtered = all.stream()
                .filter(p -> inViewport(req, p.getLatitude(), p.getLongitude()))
                .collect(Collectors.toList());

        // 4) 중복 제거: 50m 이내 & 이름 유사(공백 제거 후 포함관계)
        List<PhotoboothDto> deduped = new ArrayList<>();
        for (PhotoboothDto cur : filtered) {
            boolean dup = deduped.stream().anyMatch(x ->
                    distanceMeter(x.getLatitude(), x.getLongitude(), cur.getLatitude(), cur.getLongitude()) < 50 &&
                            (core(x.getName()).contains(core(cur.getName())) ||
                                    core(cur.getName()).contains(core(x.getName())))
            );
            if (!dup) deduped.add(cur);
        }

        // 5) 뷰포트 중앙과의 거리 계산 → 가까운 순 정렬
        double centerLat = (req.getNeLat() + req.getSwLat()) / 2.0;
        double centerLng = (req.getNeLng() + req.getSwLng()) / 2.0;

        for (PhotoboothDto dto : deduped) {
            dto.setDistanceMeter(distanceMeter(centerLat, centerLng, dto.getLatitude(), dto.getLongitude()));
        }
        deduped.sort(Comparator.comparingInt(PhotoboothDto::getDistanceMeter));

        // 6) 브랜드 필터(선택)
        if (req.getBrand() != null && !req.getBrand().isBlank()) {
            String want = req.getBrand().trim();
            deduped = deduped.stream()
                    .filter(p -> want.equalsIgnoreCase(p.getBrand()))
                    .collect(Collectors.toList());
        }

        // 7) limit 적용 (기본 300)
        int max = req.getLimit() != null ? Math.max(1, req.getLimit()) : 300;
        if (deduped.size() > max) deduped = deduped.subList(0, max);

        return deduped;
    }

    // ─────────────── helpers ───────────────

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> extractItems(Map<String, Object> response) {
        if (response == null) return List.of();
        Object items = response.get("items");
        if (items instanceof List<?> list) {
            return (List<Map<String, Object>>) list;
        }
        return List.of();
    }

    // 네이버 지역검색 아이템 → 우리 PhotoboothDto
    private PhotoboothDto toDto(Map<String, Object> item) {
        // 좌표: 네이버 Local 응답의 mapx/mapy(문자열 정수, 1e7 스케일) → 경도/위도
        double lon = parseCoord(safeStr(item.get("mapx"))); // 경도
        double lat = parseCoord(safeStr(item.get("mapy"))); // 위도

        // 장소명: <b>태그 제거
        String name = removeHtml(safeStr(item.get("title")));

        return PhotoboothDto.builder()
                .placeId(UUID.randomUUID().toString().substring(0, 8))
                .name(name)
                .brand(guessBrand(name))
                .latitude(lat)
                .longitude(lon)
                .roadAddress(safeStr(item.get("roadAddress")))
                .naverPlaceUrl(safeStr(item.get("link")))
                .distanceMeter(0) // 나중에 채움
                .cluster(false)
                .build();
    }

    // 문자열 좌표("1269251342") → 126.9251342
    private double parseCoord(String v) {
        if (v == null || v.isBlank()) return 0.0;
        try {
            return Double.parseDouble(v) / 1e7;
        } catch (NumberFormatException e) {
            return 0.0;
        }
    }

    // '<b>인생네컷</b> 홍대점' → '인생네컷 홍대점'
    private String removeHtml(String s) {
        if (s == null) return "";
        return s.replaceAll("<[^>]*>", "");
    }

    private String safeStr(Object o) {
        return o == null ? "" : String.valueOf(o);
    }

    // 간단 브랜드 추정
    private String guessBrand(String name) {
        if (name == null) return "기타";
        if (name.contains("인생네컷")) return "인생네컷";
        if (name.contains("하루필름")) return "하루필름";
        if (name.contains("포토이즘")) return "포토이즘";
        if (name.contains("포토시그널")) return "포토시그널";
        if (name.contains("포토그레이")) return "포토그레이";
        if (name.contains("돈룩업")) return "돈룩업";
        return "기타";
    }

    // 뷰포트 범위 체크
    private boolean inViewport(ViewportRequest r, double lat, double lng) {
        return lat >= r.getSwLat() && lat <= r.getNeLat()
                && lng >= r.getSwLng() && lng <= r.getNeLng();
    }

    // 두 좌표 거리(m) — 하버사인
    private int distanceMeter(double lat1, double lng1, double lat2, double lng2) {
        double R = 6371000; // m
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat/2) * Math.sin(dLat/2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng/2) * Math.sin(dLng/2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        return (int) Math.round(R * c);
    }

    // 이름 비교용 핵심 문자열
    private String core(String n) {
        return n == null ? "" : n.replace(" ", "");
    }
}
