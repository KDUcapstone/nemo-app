// backend/src/main/java/com/nemo/backend/domain/timeline/service/TimelineServiceImpl.java
package com.nemo.backend.domain.timeline.service;

import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.domain.photo.repository.PhotoRepository;
import com.nemo.backend.domain.timeline.dto.TimelineDayResponse;
import com.nemo.backend.domain.timeline.dto.TimelinePhotoItem;
import com.nemo.backend.domain.timeline.dto.TimelapseDayResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TimelineServiceImpl implements TimelineService {

    private final PhotoRepository photoRepository;

    @Override
    public List<TimelineDayResponse> getTimeline(Long userId, Integer year, Integer month) {
        // takenAt 기준 최신순 전체 조회 (삭제되지 않은 것만)
        List<Photo> photos = photoRepository.findByUserIdAndDeletedIsFalseOrderByTakenAtDesc(userId);

        Map<LocalDate, List<TimelinePhotoItem>> grouped = new LinkedHashMap<>();

        for (Photo photo : photos) {
            LocalDate date = resolveDate(photo);
            if (date == null) continue;

            // year / month 선택적 필터링 (day 없음)
            if (year != null && date.getYear() != year) continue;
            if (month != null && date.getMonthValue() != month) continue;

            PhotoResponseDto dto = new PhotoResponseDto(photo);

            TimelinePhotoItem item = new TimelinePhotoItem(
                    dto.getId(),
                    dto.getImageUrl(),
                    dto.getLocation(),
                    dto.getBrand()
            );

            grouped.computeIfAbsent(date, d -> new ArrayList<>()).add(item);
        }

        // LinkedHashMap 순서 유지 → takenAt DESC 순으로 날짜 그룹 반환
        return grouped.entrySet().stream()
                .map(entry -> new TimelineDayResponse(
                        entry.getKey().toString(), // "YYYY-MM-DD"
                        entry.getValue()
                ))
                .collect(Collectors.toList());
    }

    @Override
    public List<TimelapseDayResponse> getTimelapse(Long userId, int year, int month) {
        List<Photo> photos = photoRepository.findByUserIdAndDeletedIsFalseOrderByTakenAtDesc(userId);

        Map<LocalDate, DayStats> statsMap = new HashMap<>();

        for (Photo photo : photos) {
            LocalDate date = resolveDate(photo);
            if (date == null) continue;

            if (date.getYear() != year || date.getMonthValue() != month) continue;

            PhotoResponseDto dto = new PhotoResponseDto(photo);

            DayStats stats = statsMap.computeIfAbsent(date, d -> new DayStats());
            stats.count++;

            if (stats.thumbnailUrl == null || stats.thumbnailUrl.isBlank()) {
                String candidate = dto.getThumbnailUrl();
                if (candidate == null || candidate.isBlank()) {
                    candidate = dto.getImageUrl();
                }
                stats.thumbnailUrl = candidate;
            }
        }

        LocalDate firstDay = LocalDate.of(year, month, 1);
        int daysInMonth = firstDay.lengthOfMonth();

        List<TimelapseDayResponse> result = new ArrayList<>(daysInMonth);
        for (int d = 1; d <= daysInMonth; d++) {
            LocalDate date = LocalDate.of(year, month, d);
            DayStats stats = statsMap.get(date);

            boolean hasPhoto = stats != null && stats.count > 0;
            String thumbnailUrl = hasPhoto ? stats.thumbnailUrl : null;
            int photoCount = hasPhoto ? stats.count : 0;

            result.add(new TimelapseDayResponse(
                    date.toString(),   // "YYYY-MM-DD"
                    hasPhoto,
                    thumbnailUrl,
                    photoCount
            ));
        }

        return result;
    }

    private LocalDate resolveDate(Photo photo) {
        if (photo.getTakenAt() != null) {
            return photo.getTakenAt().toLocalDate();
        }
        if (photo.getCreatedAt() != null) {
            return photo.getCreatedAt().toLocalDate();
        }
        return null;
    }

    private static class DayStats {
        int count = 0;
        String thumbnailUrl;
    }
}
