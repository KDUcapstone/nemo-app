// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumDetailResponse.java
package com.nemo.backend.domain.album.dto;

import java.time.LocalDateTime;
import java.util.List;
import com.nemo.backend.domain.photo.dto.PhotoResponse;

public class AlbumDetailResponse {
    private Long albumId;
    private String title;
    private String description;
    private String coverPhotoUrl;
    private int photoCount;
    private LocalDateTime createdAt;
    private List<Long> photoIdList;
    private List<PhotoResponse> photoList;

    public AlbumDetailResponse() {}

    public AlbumDetailResponse(Long albumId, String title, String description,
                               String coverPhotoUrl, int photoCount, LocalDateTime createdAt,
                               List<Long> photoIdList, List<PhotoResponse> photoList) {
        this.albumId = albumId;
        this.title = title;
        this.description = description;
        this.coverPhotoUrl = coverPhotoUrl;
        this.photoCount = photoCount;
        this.createdAt = createdAt;
        this.photoIdList = photoIdList;
        this.photoList = photoList;
    }
    public Long getAlbumId() { return albumId; }
    public String getTitle() { return title; }
    public String getDescription() { return description; }
    public String getCoverPhotoUrl() { return coverPhotoUrl; }
    public int getPhotoCount() { return photoCount; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public List<Long> getPhotoIdList() { return photoIdList; }
    public List<PhotoResponse> getPhotoList() { return photoList; }
}
