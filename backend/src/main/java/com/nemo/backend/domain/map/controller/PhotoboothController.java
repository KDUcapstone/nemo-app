// src/main/java/com/nemo/backend/domain/map/controller/PhotoboothController.java
package com.nemo.backend.domain.map.controller;

import com.nemo.backend.domain.map.dto.PhotoboothDto;
import com.nemo.backend.domain.map.dto.ViewportRequest;
import com.nemo.backend.domain.map.dto.ViewportResponse;
import com.nemo.backend.domain.map.service.PhotoboothService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.concurrent.TimeUnit;

@RestController
@RequestMapping("/api/map/photobooths")
@RequiredArgsConstructor
@Tag(name = "Map-Photobooth", description = "지도·포토부스 API")
public class PhotoboothController {

    private final PhotoboothService service;

    @Operation(
            summary = "뷰포트 내 포토부스 조회",
            description = "현재 지도 화면(북동/남서 좌표) 안의 포토부스 마커들을 반환합니다.",
            security = @SecurityRequirement(name = "bearerAuth"),
            responses = {
                    @ApiResponse(responseCode = "200", description = "OK",
                            content = @Content(schema = @Schema(implementation = ViewportResponse.class))),
                    @ApiResponse(responseCode = "400", description = "잘못된 파라미터"),
                    @ApiResponse(responseCode = "503", description = "외부 API 과호출 등으로 일시적 실패")
            }
    )
    @GetMapping("/viewport")
    public ResponseEntity<ViewportResponse> viewport(
            @Parameter(description = "북동 위도", example = "37.5750") @RequestParam double neLat,
            @Parameter(description = "북동 경도", example = "126.9850") @RequestParam double neLng,
            @Parameter(description = "남서 위도", example = "37.5580") @RequestParam double swLat,
            @Parameter(description = "남서 경도", example = "126.9700") @RequestParam double swLng,
            @Parameter(description = "줌 레벨", example = "14") @RequestParam(defaultValue = "14") Integer zoom,
            @Parameter(description = "브랜드 필터", example = "인생네컷") @RequestParam(required = false) String brand,
            @Parameter(description = "최대 개수", example = "300") @RequestParam(defaultValue = "300") Integer limit,
            @Parameter(description = "클러스터 여부", example = "true") @RequestParam(defaultValue = "true") Boolean cluster
    ) {
        // 1) 기본 검증: 좌표 범위/관계 체크
        if (!validLat(neLat) || !validLat(swLat) || !validLng(neLng) || !validLng(swLng)) {
            return ResponseEntity.badRequest().build();
        }
        if (neLat <= swLat || neLng <= swLng) {
            return ResponseEntity.badRequest().build();
        }

        // 2) 요청 DTO 구성 (빈 문자열은 null 처리)
        ViewportRequest req = new ViewportRequest();
        req.setNeLat(neLat); req.setNeLng(neLng);
        req.setSwLat(swLat); req.setSwLng(swLng);
        req.setZoom(zoom);
        req.setBrand(blankToNull(brand));
        req.setLimit(limit);
        req.setCluster(Boolean.TRUE.equals(cluster)); // 현재는 미사용이어도 스펙 유지

        // 3) 서비스 호출
        List<PhotoboothDto> items = service.getPhotoboothsInViewport(req);

        // 4) 응답 DTO 조립
        ViewportResponse body = ViewportResponse.builder()
                .items(items)
                .viewport(ViewportResponse.ViewportMeta.builder()
                        .neLat(neLat).neLng(neLng)
                        .swLat(swLat).swLng(swLng)
                        .zoom(zoom)
                        .build())
                .serverTs(Instant.now())
                .build();

        // 5) 가벼운 캐시 힌트(수 초면 충분) — 프론트가 빠르게 같은 뷰포트 재요청 시 도움
        CacheControl cc = CacheControl.maxAge(5, TimeUnit.SECONDS).cachePublic();

        return ResponseEntity.ok()
                .cacheControl(cc)
                .body(body);
    }

    // ────────── helpers ──────────
    private boolean validLat(double v) { return v >= -90 && v <= 90; }
    private boolean validLng(double v) { return v >= -180 && v <= 180; }
    private String blankToNull(String s) { return (s == null || s.isBlank()) ? null : s; }
}
