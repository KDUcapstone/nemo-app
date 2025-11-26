// backend/src/main/java/com/nemo/backend/domain/timeline/controller/TimelineController.java
package com.nemo.backend.domain.timeline.controller;

import com.nemo.backend.domain.auth.util.AuthExtractor;
import com.nemo.backend.domain.timeline.dto.TimelineDayResponse;
import com.nemo.backend.domain.timeline.dto.TimelapseDayResponse;
import com.nemo.backend.domain.timeline.service.TimelineService;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Timeline", description = "캘린더 타임라인 / 타임랩스 API")
@SecurityRequirement(name = "BearerAuth")
@RestController
@RequestMapping(
        value = "/api/timeline",
        produces = "application/json; charset=UTF-8"
)
@RequiredArgsConstructor
public class TimelineController {

    private final TimelineService timelineService;
    private final AuthExtractor authExtractor;

    /**
     * ✅ 타임라인 조회
     * GET /api/timeline?year=2025&month=7
     * year, month 둘 다 선택 (없으면 전체)
     */
    @Operation(
            summary = "타임라인 조회",
            description = "로그인한 사용자의 사진을 날짜순으로 나열해 타임라인 형태로 조회합니다."
    )
    @GetMapping
    public ResponseEntity<List<TimelineDayResponse>> getTimeline(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @RequestParam(value = "year", required = false) Integer year,
            @RequestParam(value = "month", required = false) Integer month
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);
        List<TimelineDayResponse> timeline = timelineService.getTimeline(userId, year, month);
        return ResponseEntity.ok(timeline);
    }

    /**
     * ✅ 캘린더 타임랩스 조회
     * GET /api/timeline/timelapse?year=2025&month=7
     * year, month 필수
     */
    @Operation(
            summary = "캘린더 타임랩스 조회",
            description = "선택한 월(month)의 달력에 사진 촬영 여부 및 대표 이미지를 표시합니다."
    )
    @GetMapping("/timelapse")
    public ResponseEntity<List<TimelapseDayResponse>> getTimelapse(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @RequestParam(value = "year", required = false) Integer year,
            @RequestParam(value = "month", required = false) Integer month
    ) {
        if (year == null || month == null) {
            // 명세서에 정의된 INVALID_QUERY 그대로 사용
            throw new ApiException(ErrorCode.INVALID_QUERY, "year와 month 파라미터는 필수입니다.");
        }

        Long userId = authExtractor.extractUserId(authorizationHeader);
        List<TimelapseDayResponse> result = timelineService.getTimelapse(userId, year, month);
        return ResponseEntity.ok(result);
    }
}
