// backend/src/main/java/com/nemo/backend/domain/photo/entity/Photo.java
package com.nemo.backend.domain.photo.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

/**
 * 사진 1장(레코드) + 연계 정보 엔티티.
 * (QR 중복 해시 사용 X)
 */
@Entity
@Table(name = "photos")
public class Photo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long userId;

    @Column(nullable = false)
    private String imageUrl;

    /** 썸네일용 (API 응답에는 노출 안 함) */
    private String thumbnailUrl;

    private LocalDateTime takenAt;

    /** 명세서의 location 필드 (장소 문자열) */
    @Column(name = "location")
    private String location;

    private String brand;

    /** 즐겨찾기 여부 (기본 false) */
    @Column(name = "favorite")
    private Boolean favorite = false;

    /** 메모(상세 편집에서 사용하는 필드) */
    @Column(name = "memo", length = 300)
    private String memo;

    private LocalDateTime createdAt = LocalDateTime.now();
    private Boolean deleted = false;

    public Photo() {
    }

    public Photo(
            Long userId,
            String imageUrl,
            String thumbnailUrl,
            String brand,
            LocalDateTime takenAt,
            String location
    ) {
        this.userId = userId;
        this.imageUrl = imageUrl;
        this.thumbnailUrl = thumbnailUrl;
        this.brand = brand;
        this.takenAt = takenAt;
        this.location = location;
    }

    // --- getters/setters ---
    public Long getId() { return id; }

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }

    public String getThumbnailUrl() { return thumbnailUrl; }
    public void setThumbnailUrl(String thumbnailUrl) { this.thumbnailUrl = thumbnailUrl; }

    public LocalDateTime getTakenAt() { return takenAt; }
    public void setTakenAt(LocalDateTime takenAt) { this.takenAt = takenAt; }

    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }

    public String getBrand() { return brand; }
    public void setBrand(String brand) { this.brand = brand; }

    public Boolean getFavorite() { return favorite; }
    public void setFavorite(Boolean favorite) { this.favorite = favorite; }

    public String getMemo() { return memo; }
    public void setMemo(String memo) { this.memo = memo; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public Boolean getDeleted() { return deleted; }
    public void setDeleted(Boolean deleted) { this.deleted = deleted; }
}
