package com.nemo.backend.domain.map.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.List;

/**
 * 뷰포트 증분(Delta) 조회 응답 DTO
 *
 * - added   : 새로 생긴 마커(또는 처음 내려가는 마커)
 * - updated : 기존에 있던 마커 중에서 내용이 바뀐 마커
 * - removed : 더 이상 이 뷰포트 안에 존재하지 않는 마커 ID
 * - serverTs: 이번 응답의 기준 시각 (다음 요청의 sinceTs로 사용)
 */
@Data
@Builder
public class ViewportDeltaResponse {

    /**
     * 새로 추가된 마커 목록
     * - 클라이언트가 knownIds로 보내지 않았던 것들 중,
     *   현재 뷰포트 안에 새로 등장한 마커들
     */
    private List<PhotoboothDto> added;

    /**
     * 업데이트된 마커 목록
     * - 클라이언트가 이미 알고 있던 ID이긴 하지만,
     *   좌표/이름/브랜드 등이 변경된 마커들
     */
    private List<PhotoboothDto> updated;

    /**
     * 제거된 마커 ID 목록
     * - 클라이언트는 알고 있었지만(knownIds에 있었음),
     *   현재 서버 기준 뷰포트 안에 더 이상 존재하지 않는 ID들
     * - 프론트에서는 이 ID들을 지도에서 삭제하면 된다.
     */
    private List<String> removedIds;

    /**
     * 서버 응답 시각
     * - 클라이언트는 이 값을 그대로 저장해 두었다가
     *   다음 /viewport/delta 요청의 sinceTs로 보내면 된다.
     */
    private Instant serverTs;
}
