// backend/src/main/java/com/nemo/backend/domain/timeline/dto/TimelinePhotoItem.java
package com.nemo.backend.domain.timeline.dto;

public record TimelinePhotoItem(
        long photoId,
        String imageUrl,
        String location,
        String brand
) {}
