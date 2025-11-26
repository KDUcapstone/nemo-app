// backend/src/main/java/com/nemo/backend/domain/timeline/service/TimelineService.java
package com.nemo.backend.domain.timeline.service;

import com.nemo.backend.domain.timeline.dto.TimelineDayResponse;
import com.nemo.backend.domain.timeline.dto.TimelapseDayResponse;

import java.util.List;

public interface TimelineService {

    /**
     * 타임라인 조회
     * year, month는 선택 필터 (nullable)
     */
    List<TimelineDayResponse> getTimeline(Long userId, Integer year, Integer month);

    /**
     * 캘린더 타임랩스 조회
     * year, month 필수
     */
    List<TimelapseDayResponse> getTimelapse(Long userId, int year, int month);
}
