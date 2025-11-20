// src/main/java/com/nemo/backend/domain/map/service/PhotoboothService.java
package com.nemo.backend.domain.map.service;

import com.nemo.backend.domain.map.dto.PhotoboothDto;
import com.nemo.backend.domain.map.dto.ViewportDeltaRequest;
import com.nemo.backend.domain.map.dto.ViewportDeltaResponse;
import com.nemo.backend.domain.map.dto.ViewportRequest;
import com.nemo.backend.domain.map.util.NaverApiClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

/**
 * 📌 PhotoboothService
 * ─────────────────────────────────────────────────────────────────────
 * 1) 클라이언트가 보낸 '현재 지도 뷰포트(화면)' 정보를 받는다.
 * 2) 뷰포트 중심 좌표를 기준으로 네이버 Reverse Geocoding 호출 → "강남구 역삼동"
 * 3) 이 지역명을 기반으로 네이버 Local Search(장소 검색) 실행
 *     예) "강남구 역삼동 인생네컷", "강남구 역삼동 포토부스"
 * 4) 검색 결과 중 실제 뷰포트 안에 포함되는 포토부스만 필터링
 * 5) 중복 제거(50m 이내 + 이름 유사)
 * 6) 거리 기준 정렬
 * 7) 브랜드 필터 / LIMIT 적용
 * ─────────────────────────────────────────────────────────────────────
 */

@Slf4j
@Service
@RequiredArgsConstructor
public class PhotoboothService {

    private final NaverApiClient naverApiClient;

    // 🔍 기본 검색 키워드(브랜드 + 일반 키워드)
    private static final List<String> KEYWORDS = List.of(
            "포토부스", "인생네컷", "하루필름", "포토이즘", "포토시그널", "포토그레이", "돈룩업"
    );

    private static final int PAGE_SIZE = 5;               // 네이버 LocalSearch 최대 display=5
    private static final int MAX_PAGES_PER_KEYWORD = 4;   // 한 키워드당 최대 20개 수집

    /**
     * 뷰포트 증분(Delta) 조회
     *
     * - 현재 뷰포트 기준 전체 마커 목록을 한 번 계산한 뒤,
     *   클라이언트가 보낸 knownIds / sinceTs를 이용해
     *   added / updated / removed를 나눠서 반환한다.
     *
     * 🧠 핵심 아이디어
     *  1) current  = 현재 서버 기준 뷰포트 안의 마커들
     *  2) knownIds = 클라이언트가 이미 가지고 있는 마커 ID들
     *
     *  - added   : current에는 있는데, knownIds에는 없는 ID
     *  - removed : knownIds에는 있는데, current에는 없는 ID
     *  - updated : 둘 다에 있지만, 내용이 바뀐 마커
     */
    public ViewportDeltaResponse getPhotoboothsDelta(ViewportDeltaRequest req) {

        // 1) Delta 요청을 기존 전체 조회용 ViewportRequest로 변환
        ViewportRequest viewportReq = toViewportRequest(req);

        // 2) 현재 뷰포트 기준 전체 마커 목록 계산
        //    → 이미 구현되어 있는 메서드 재사용
        List<PhotoboothDto> current = getPhotoboothsInViewport(viewportReq);

        Instant serverTs = Instant.now(); // 이번 응답 기준 시각

        // 현재 뷰포트 안에 존재하는 placeId 집합
        Set<String> currentIds = current.stream()
                .map(PhotoboothDto::getPlaceId)
                .collect(Collectors.toSet());

        // 클라이언트가 알고 있는 placeId 집합 (null-safe)
        Set<String> clientKnown = Optional.ofNullable(req.getKnownIds())
                .map(HashSet::new)
                .orElseGet(HashSet::new);

        // ----------------------------------------
        // 3-1) added = 서버에는 있고, 클라이언트엔 없는 마커
        // ----------------------------------------
        List<PhotoboothDto> added = current.stream()
                .filter(dto -> !clientKnown.contains(dto.getPlaceId()))
                .toList();

        // ----------------------------------------
        // 3-2) updated = ID는 같지만 내용이 바뀐 마커
        //  - 여기서는 lastUpdated가 sinceTs 이후인지 여부로 판단하거나,
        //    비교 필드를 직접 비교하는 방식으로 구현한다.
        // ----------------------------------------
        List<PhotoboothDto> updated = current.stream()
                .filter(dto -> clientKnown.contains(dto.getPlaceId()))
                .filter(dto -> hasChangedSince(dto, req.getSinceTs()))
                .toList();

        // ----------------------------------------
        // 3-3) removed = 클라이언트는 알고 있지만,
        //       현재 뷰포트 안에는 더 이상 존재하지 않는 마커 ID
        // ----------------------------------------
        List<String> removedIds = clientKnown.stream()
                .filter(id -> !currentIds.contains(id))
                .toList();

        log.info("[MAP][DELTA] viewport=({},{} ~ {},{}), added={}, updated={}, removed={}",
                viewportReq.getNeLat(), viewportReq.getNeLng(),
                viewportReq.getSwLat(), viewportReq.getSwLng(),
                added.size(), updated.size(), removedIds.size()
        );

        return ViewportDeltaResponse.builder()
                .added(added)
                .updated(updated)
                .removedIds(removedIds)
                .serverTs(serverTs)
                .build();
    }

    /**
     * Delta 요청(ViewportDeltaRequest)을
     * 기존 뷰포트 전체 조회용 ViewportRequest로 변환하는 헬퍼 메서드.
     *
     * - brand, limit, zoom 등은 프로젝트 정책에 맞게 세팅하면 된다.
     */
    private ViewportRequest toViewportRequest(ViewportDeltaRequest req) {
        ViewportRequest v = new ViewportRequest();
        v.setNeLat(req.getNeLat());
        v.setNeLng(req.getNeLng());
        v.setSwLat(req.getSwLat());
        v.setSwLng(req.getSwLng());
        v.setBrand(req.getBrand());
        v.setLimit(300); // Delta에서도 최대 300개 정도만 가져오도록 가드
        // v.setZoom( ... ) // 필요하면 추후 추가
        return v;
    }

    /**
     * 마커가 sinceTs 이후로 변경되었는지 여부를 판단하는 헬퍼.
     *
     * - 간단한 버전: DTO 안에 lastUpdated 필드가 있다고 가정하고 비교
     * - 더 심플한 버전: sinceTs가 null이면 "무조건 변경 없음" 또는
     *   "무조건 변경 있음" 정책 중 하나를 택해서 구현할 수 있다.
     *
     * 지금 단계에서는 예시로만 두고,
     * 실제 로직은 DB/캐시 구조 설계에 맞춰 수정하면 된다.
     */
    private boolean hasChangedSince(PhotoboothDto dto, Instant sinceTs) {
        if (sinceTs == null) {
            // sinceTs가 없으면 "변경 여부 판단 X → 업데이트 없음"으로 가정
            return false;
        }

        // 🔧 예시: DTO에 lastUpdated가 있을 때
        if (dto.getLastUpdated() == null) {
            return false;
        }
        return dto.getLastUpdated().isAfter(sinceTs);
    }

    /**
     * 📌 현재 뷰포트 안에 존재하는 포토부스 반환
     */
    public List<PhotoboothDto> getPhotoboothsInViewport(ViewportRequest req) {

        // ────────────────────────────────────────
        // 1) 뷰포트 중심 좌표 계산
        // ────────────────────────────────────────
        double centerLat = (req.getNeLat() + req.getSwLat()) / 2.0;
        double centerLng = (req.getNeLng() + req.getSwLng()) / 2.0;

        // ────────────────────────────────────────
        // 2) Reverse Geocoding → "강남구 역삼동" 같이 지역명 얻기
        // ────────────────────────────────────────
        Optional<String> regionOpt = naverApiClient.reverseGeocodeToRegion(centerLat, centerLng);
        String regionName = regionOpt.orElse(null);

        // ⭐ 로그(1) — 요청된 뷰포트 + 중심 + 역지오코딩 결과
        log.info("[MAP][REQ] ne=({}, {}), sw=({}, {}), center=({}, {}), region='{}'",
                req.getNeLat(), req.getNeLng(),
                req.getSwLat(), req.getSwLng(),
                centerLat, centerLng,
                regionName
        );

        // ────────────────────────────────────────
        // 3) 실제 네이버 검색에 사용할 키워드 구성
        //    ▷ 위치 기반 정확한 검색을 위해 "지역명 + 키워드" 형태 선호
        //      예: "강남구 역삼동 인생네컷"
        // ────────────────────────────────────────
        List<String> searchKeywords = new ArrayList<>();

        if (regionName != null && !regionName.isBlank()) {
            for (String base : KEYWORDS) {
                searchKeywords.add(regionName + " " + base);
            }
            // 보조 키워드 하나 더
            searchKeywords.add(regionName + " 포토부스");
        } else {
            // 역지오코딩 실패 시 → 전국 검색 fallback
            searchKeywords.addAll(KEYWORDS);
        }

        // ⭐ 로그(2) — 사용된 검색 키워드 목록 출력
        log.info("[MAP][KEYWORDS] {}", searchKeywords);

        // ────────────────────────────────────────
        // 4) 네이버 Local Search 호출 (키워드 × 페이지)
        // ────────────────────────────────────────
        List<Map<String, Object>> raw = new ArrayList<>();

        for (String kw : searchKeywords) {
            int page = 0;
            boolean hasMore = true;

            while (hasMore && page < MAX_PAGES_PER_KEYWORD) {
                page++;

                // start는 1부터 시작 (1, 6, 11, 16...)
                int start = 1 + (page - 1) * PAGE_SIZE;

                Map<String, Object> res = naverApiClient.searchLocal(kw, PAGE_SIZE, start, "random");
                List<Map<String, Object>> items = extractItems(res);

                if (items.isEmpty()) {
                    hasMore = false;  // 다음 페이지 없음
                } else {
                    raw.addAll(items);
                    if (items.size() < PAGE_SIZE) hasMore = false; // 마지막 페이지
                }
            }
        }

        // ⭐ 로그(3) — 네이버 LocalSearch 결과 총합
        log.info("[MAP][RAW] totalRawItems={}", raw.size());

        // ────────────────────────────────────────
        // 5) raw → PhotoboothDto (좌표 변환, 브랜드 추정, HTML 제거)
        // ────────────────────────────────────────
        List<PhotoboothDto> all = raw.stream()
                .map(this::toDto)
                .filter(dto -> dto.getLatitude() != 0 && dto.getLongitude() != 0) // 좌표 없는 경우 제외
                .toList();

        // ────────────────────────────────────────
        // 6) 실제 뷰포트 안에 포함되는 후보만 필터링
        // ────────────────────────────────────────
        List<PhotoboothDto> filtered = all.stream()
                .filter(p -> inViewport(req, p.getLatitude(), p.getLongitude()))
                .toList();

        // ⭐ 로그(4) — 뷰포트 안에 실제로 존재하는 결과 수
        log.info("[MAP][FILTER] inViewport={}", filtered.size());

        // ────────────────────────────────────────
        // 7) 중복 제거 (50m 이내 + 이름 유사)
        //    ▷ 네이버 검색 결과 특성상 동일한 지점이 여러 키워드에서 중복으로 나올 수 있음
        // ────────────────────────────────────────
        List<PhotoboothDto> deduped = new ArrayList<>();
        for (PhotoboothDto cur : filtered) {
            boolean dup = deduped.stream().anyMatch(x ->
                    distanceMeter(x.getLatitude(), x.getLongitude(), cur.getLatitude(), cur.getLongitude()) < 50 &&
                            (core(x.getName()).contains(core(cur.getName())) ||
                                    core(cur.getName()).contains(core(x.getName())))
            );
            if (!dup) deduped.add(cur);
        }

        // ⭐ 로그(5) — dedupe 후 결과
        log.info("[MAP][DEDUP] deduped={}", deduped.size());


        // ────────────────────────────────────────
        // 8) 뷰포트 중심과의 거리 계산 후 오름차순 정렬
        // ────────────────────────────────────────
        for (PhotoboothDto dto : deduped) {
            dto.setDistanceMeter(distanceMeter(centerLat, centerLng, dto.getLatitude(), dto.getLongitude()));
        }
        deduped.sort(Comparator.comparingInt(PhotoboothDto::getDistanceMeter));

        // ────────────────────────────────────────
        // 9) 브랜드 필터 (요청 시)
        // ────────────────────────────────────────
        if (req.getBrand() != null && !req.getBrand().isBlank()) {
            String want = req.getBrand().trim();
            deduped = deduped.stream()
                    .filter(p -> want.equalsIgnoreCase(p.getBrand()))
                    .collect(Collectors.toList());
        }

        // ────────────────────────────────────────
        // 10) LIMIT 적용 (기본=300)
        // ────────────────────────────────────────
        int max = req.getLimit() != null ? Math.max(1, req.getLimit()) : 300;
        if (deduped.size() > max) deduped = deduped.subList(0, max);

        // ⭐ 로그(6) — 최종 반환 개수
        log.info("[MAP][RETURN] finalCount={}", deduped.size());

        return deduped;
    }

    // ───────────────────────────────────────────────
    // helpers
    // ───────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> extractItems(Map<String, Object> response) {
        if (response == null) return List.of();
        Object items = response.get("items");
        if (items instanceof List<?> list) {
            return (List<Map<String, Object>>) list;
        }
        return List.of();
    }

    // 네이버 지역검색 응답 item → PhotoboothDto 변환
    private PhotoboothDto toDto(Map<String, Object> item) {
        double lon = parseCoord(safeStr(item.get("mapx"))); // 경도
        double lat = parseCoord(safeStr(item.get("mapy"))); // 위도
        String name = removeHtml(safeStr(item.get("title")));

        return PhotoboothDto.builder()
                .placeId(UUID.randomUUID().toString().substring(0, 8))
                .name(name)
                .brand(guessBrand(name))
                .latitude(lat)
                .longitude(lon)
                .roadAddress(safeStr(item.get("roadAddress")))
                .naverPlaceUrl(safeStr(item.get("link")))
                .distanceMeter(0)
                .cluster(false)
                .build();
    }

    private double parseCoord(String v) {
        if (v == null || v.isBlank()) return 0.0;
        try {
            return Double.parseDouble(v) / 1e7;
        } catch (NumberFormatException e) {
            return 0.0;
        }
    }

    private String safeStr(Object o) {
        return o == null ? "" : String.valueOf(o);
    }

    private String removeHtml(String s) {
        if (s == null) return "";
        return s.replaceAll("<[^>]*>", "");
    }

    // 간단 브랜드 추정 로직
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

    // 하버사인 거리(m)
    private int distanceMeter(double lat1, double lng1, double lat2, double lng2) {
        double R = 6371000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat/2) * Math.sin(dLat/2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng/2) * Math.sin(dLng/2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return (int) Math.round(R * c);
    }

    private String core(String n) {
        return n == null ? "" : n.replace(" ", "");
    }
}
