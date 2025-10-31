// backend/src/main/java/com/nemo/backend/domain/photo/dto/PhotoResponse.java
package com.nemo.backend.domain.photo.dto;

import java.time.LocalDateTime;

public class PhotoResponse {
    private Long photoId;
    private String imageUrl;
    private LocalDateTime takenAt;
    private String location;
    private String brand;

    public PhotoResponse() {}
    public PhotoResponse(Long photoId, String imageUrl, LocalDateTime takenAt, String location, String brand) {
        this.photoId = photoId;
        this.imageUrl = imageUrl;
        this.takenAt = takenAt;
        this.location = location;
        this.brand = brand;
    }
    public Long getPhotoId() { return photoId; }
    public String getImageUrl() { return imageUrl; }
    public LocalDateTime getTakenAt() { return takenAt; }
    public String getLocation() { return location; }
    public String getBrand() { return brand; }
}
