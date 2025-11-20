// src/main/java/com/nemo/backend/domain/map/dto/PhotoboothDto.java
package com.nemo.backend.domain.map.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;

@Data
@Builder
@AllArgsConstructor
public class PhotoboothDto {
    // ✅ 프론트 마커의 고유 key (간단히 임의 ID 사용)
    private String placeId;

    // ✅ 화면에 보여줄 이름(HTML 태그 제거된 순수 텍스트)
    private String name;

    // ✅ 간단 브랜드 추정값(이름에 '인생네컷' 포함 등 규칙)
    private String brand;

    // ✅ 지도에 찍을 좌표(위도/경도)
    private double latitude;
    private double longitude;

    // ✅ 주소/링크(있으면 제공)
    private String roadAddress;
    private String naverPlaceUrl;

    // ✅ 중심점(뷰포트 중앙)과의 거리(미터) — 가까운 순으로 정렬에 사용
    private int distanceMeter;

    // ✅ 클러스터 마커 관련(지금은 false 고정)
    private boolean cluster;
    private Integer count;      // 클러스터에 포함된 개수(미사용)
    private Integer bucketSize; // 클러스터 반경 힌트(미사용)

    //✅ 마지막 수정 시각 (내부용, 응답에 포함하지 않음)
    @JsonIgnore
    private Instant lastUpdated;
}
