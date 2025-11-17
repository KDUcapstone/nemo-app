// src/main/java/com/nemo/backend/domain/map/dto/PhotoboothViewportResponse.java
package com.nemo.backend.domain.map.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.*;

import java.time.Instant;
import java.util.List;

@Getter @Setter @Builder
@NoArgsConstructor @AllArgsConstructor
@Schema(description = "뷰포트 포토부스 조회 응답")
public class ViewportResponse {

    @Schema(description = "마커 목록")
    private List<PhotoboothDto> items;

    @Schema(description = "요청한 뷰포트 메타 정보")
    private ViewportMeta viewport;

    @Schema(description = "서버 타임스탬프(ISO-8601)")
    private Instant serverTs;

    @Getter @Setter @Builder
    @NoArgsConstructor @AllArgsConstructor
    @Schema(description = "뷰포트(북동/남서/줌)")
    public static class ViewportMeta {
        private double neLat;
        private double neLng;
        private double swLat;
        private double swLng;
        private Integer zoom;
    }
}
