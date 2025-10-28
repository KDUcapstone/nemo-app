package com.nemo.backend.domain.photo.dto;

import com.nemo.backend.domain.photo.entity.Photo;
import java.time.LocalDateTime;

public class PhotoResponseDto {
    private Long id;
    private Long userId;
    private Long albumId;
    private String imageUrl;
    private String thumbnailUrl;
    private String videoUrl;
    private String brand;
    private LocalDateTime takenAt;
    private Long locationId;
    private String qrHash;
    private LocalDateTime createdAt;

    public PhotoResponseDto(Photo photo) {
        this.id = photo.getId();
        this.userId = photo.getUserId();
        this.albumId = (photo.getAlbum() != null ? photo.getAlbum().getId() : null);
        this.imageUrl = photo.getImageUrl();
        this.thumbnailUrl = photo.getThumbnailUrl();
        this.videoUrl = photo.getVideoUrl();
        this.brand = photo.getBrand();
        this.takenAt = photo.getTakenAt();
        this.locationId = photo.getLocationId();
        this.qrHash = photo.getQrHash();
        this.createdAt = photo.getCreatedAt();
    }

    // getters
    public Long getId() { return id; }
    public Long getUserId() { return userId; }
    public Long getAlbumId() { return albumId; }
    public String getImageUrl() { return imageUrl; }
    public String getThumbnailUrl() { return thumbnailUrl; }
    public String getVideoUrl() { return videoUrl; }
    public String getBrand() { return brand; }
    public LocalDateTime getTakenAt() { return takenAt; }
    public Long getLocationId() { return locationId; }
    public String getQrHash() { return qrHash; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
