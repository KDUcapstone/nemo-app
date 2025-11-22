// backend/src/main/java/com/nemo/backend/domain/timeline/dto/TimelineDayResponse.java
package com.nemo.backend.domain.timeline.dto;

import java.util.List;

public record TimelineDayResponse(
        String date,              // "YYYY-MM-DD"
        List<TimelinePhotoItem> photos
) {}
