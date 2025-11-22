// backend/src/main/java/com/nemo/backend/domain/timeline/dto/TimelapseDayResponse.java
package com.nemo.backend.domain.timeline.dto;

public record TimelapseDayResponse(
        String date,         // "YYYY-MM-DD"
        boolean hasPhoto,
        String thumbnailUrl,
        int photoCount
) {}
