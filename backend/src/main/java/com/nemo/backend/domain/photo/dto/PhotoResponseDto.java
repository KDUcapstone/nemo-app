// backend/src/main/java/com/nemo/backend/domain/photo/dto/PhotoResponseDto.java
package com.nemo.backend.domain.photo.dto;

import com.nemo.backend.domain.photo.entity.Photo;

import java.time.LocalDateTime;

/**
 * 사진 상세/목록 조회용 DTO (서비스 ↔ 컨트롤러 내부용).
 * 실제 API 응답은 컨트롤러의 별도 DTO로 감싼다.
 */
public class PhotoResponseDto {
    private Long id;
    private Long userId;
    private Long albumId;
    private String imageUrl;
    private String thumbnailUrl;
    private String brand;
    private LocalDateTime takenAt;
    private String location;        // 명세: location 문자열 하나
    private String qrHash;
    private LocalDateTime createdAt;
    private boolean favorite;
    private String memo;

    public PhotoResponseDto(Photo photo) {
        this.id = photo.getId();
        this.userId = photo.getUserId();
        this.albumId = photo.getAlbumId();
        this.imageUrl = photo.getImageUrl();
        this.thumbnailUrl = photo.getThumbnailUrl();
        this.brand = photo.getBrand();
        this.takenAt = photo.getTakenAt();
        this.location = photo.getLocation();
        this.qrHash = photo.getQrHash();
        this.createdAt = photo.getCreatedAt();
        this.favorite = Boolean.TRUE.equals(photo.getFavorite());
        this.memo = photo.getMemo();
    }

    public Long getId() { return id; }
    public Long getUserId() { return userId; }
    public Long getAlbumId() { return albumId; }
    public String getImageUrl() { return imageUrl; }
    public String getThumbnailUrl() { return thumbnailUrl; }
    public String getBrand() { return brand; }
    public LocalDateTime getTakenAt() { return takenAt; }
    public String getLocation() { return location; }
    public String getQrHash() { return qrHash; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public boolean isFavorite() { return favorite; }
    public String getMemo() { return memo; }
}
