// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumSummaryResponse.java
package com.nemo.backend.domain.album.dto;

import java.time.LocalDateTime;

/**
 * 앨범 목록 아이템 DTO.
 * 프론트 사용 필드: albumId, title, coverPhotoUrl, photoCount, createdAt
 */
public class AlbumSummaryResponse {
    private Long albumId;
    private String title;
    private String coverPhotoUrl;
    private int photoCount;
    private LocalDateTime createdAt;

    public AlbumSummaryResponse() {}

    public AlbumSummaryResponse(Long albumId, String title, String coverPhotoUrl, int photoCount, LocalDateTime createdAt) {
        this.albumId = albumId;
        this.title = title;
        this.coverPhotoUrl = coverPhotoUrl;
        this.photoCount = photoCount;
        this.createdAt = createdAt;
    }

    public Long getAlbumId() { return albumId; }
    public String getTitle() { return title; }
    public String getCoverPhotoUrl() { return coverPhotoUrl; }
    public int getPhotoCount() { return photoCount; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
