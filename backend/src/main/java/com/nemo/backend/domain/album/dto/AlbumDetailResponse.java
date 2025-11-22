// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumDetailResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 앨범 상세 조회 응답
 * 명세: albumId, title, description, coverPhotoUrl, photoCount, createdAt, role, photoList[]
 */
@Getter
@Builder
public class AlbumDetailResponse {

    private Long albumId;
    private String title;
    private String description;
    private String coverPhotoUrl;
    private int photoCount;
    private LocalDateTime createdAt;
    private String role;   // OWNER / CO_OWNER / EDITOR / VIEWER
    private List<PhotoSummary> photoList;

    @Getter
    @AllArgsConstructor
    public static class PhotoSummary {
        private Long photoId;
        private String imageUrl;
        private LocalDateTime takenAt;
        private String location;   // ✅ 명세: location (문자열만)
        private String brand;      // ✅ 명세: brand
        // ❌ locationId / locationName / videoUrl 전부 없음
    }
}
