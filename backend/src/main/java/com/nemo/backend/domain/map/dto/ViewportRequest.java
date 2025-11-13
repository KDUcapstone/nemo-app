// src/main/java/com/nemo/backend/domain/map/dto/ViewportRequest.java
package com.nemo.backend.domain.map.dto;

import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class ViewportRequest {
    // ✅ 지도의 '현재 화면'을 감싸는 직사각형(뷰포트)의 네 꼭짓점 좌표(북동/남서)
    private double neLat; // 북동 위도
    private double neLng; // 북동 경도
    private double swLat; // 남서 위도
    private double swLng; // 남서 경도

    // ✅ 선택 파라미터 (없어도 동작)
    private Integer zoom;     // 줌 레벨(정렬/클러스터링 힌트 용)
    private String brand;     // 브랜드 필터(인생네컷/하루필름 등)
    private Integer limit;    // 최대 반환 개수(기본 300)
    private Boolean cluster;  // 클러스터 사용 여부(MVP에서는 무시)
}
