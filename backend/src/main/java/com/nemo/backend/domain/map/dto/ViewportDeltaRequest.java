package com.nemo.backend.domain.map.dto;

import lombok.Data;

import java.time.Instant;
import java.util.List;

/**
 * 뷰포트 증분(Delta) 조회용 요청 DTO
 *
 * - 클라이언트가 현재 보고 있는 지도 영역(뷰포트) 정보 +
 *   마지막으로 데이터를 받은 시각(sinceTs) +
 *   이미 가지고 있는 마커 ID 목록(knownIds)을 보내면,
 *   서버는 그 이후로 변경된 부분만 돌려준다.
 */
@Data
public class ViewportDeltaRequest {

    // -------------------------------
    // 1) 뷰포트(현재 보고 있는 지도 영역) 정보
    // -------------------------------

    /** 북동쪽 모서리 위도 (top-right) */
    private double neLat;

    /** 북동쪽 모서리 경도 (top-right) */
    private double neLng;

    /** 남서쪽 모서리 위도 (bottom-left) */
    private double swLat;

    /** 남서쪽 모서리 경도 (bottom-left) */
    private double swLng;

    // -------------------------------
    // 2) Delta 기준 정보
    // -------------------------------

    /**
     * 기준 시각
     * - 클라이언트 입장: "이 시각 이후로 바뀐 것만 보내줘"
     * - 서버 입장: 이 값을 기준으로 added/updated/removed 계산
     * - ISO 8601 형식 문자열로 들어오고, 컨트롤러에서 Instant로 변환 가능
     */
    private Instant sinceTs;

    /**
     * 클라이언트가 이미 가지고 있는 마커의 placeId 목록
     * - 예: ["pb_1", "pb_2", "pb_3"]
     * - 서버는 이 목록과 현재 상태를 비교해서
     *   added / updated / removed 를 계산한다.
     */
    private List<String> knownIds;

    // -------------------------------
    // 3) 선택 필터
    // -------------------------------

    /**
     * 브랜드 필터 (선택)
     * - null 또는 빈 문자열("") 이면 전체 브랜드 대상
     * - "인생네컷" 등 특정 브랜드만 보고 싶을 때 사용
     */
    private String brand;

    /**
     * 클러스터 옵션 (선택)
     * - 지금 단계에서는 아직 사용하지 않고 무시해도 됨
     * - 나중에 클러스터링 기능을 붙이고 싶을 때 확장 가능
     */
    private Boolean cluster;
}
