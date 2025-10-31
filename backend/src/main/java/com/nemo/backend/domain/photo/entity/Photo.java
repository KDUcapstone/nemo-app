package com.nemo.backend.domain.photo.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import com.nemo.backend.domain.album.entity.Album;

/**
 * 사진 1장(레코드) + 연계 동영상 URL을 함께 저장하기 위한 엔티티.
 * QR 해시(qrHash)로 중복 업로드를 방지한다.
 */
@Entity
@Table(name = "photos", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"qrHash"})
})
public class Photo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 소유자(회원) ID */
    private Long userId;

    /** 앨범 연결 (nullable) */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "album_id")
    private Album album;

    /** 원본 이미지 URL (필수) */
    @Column(nullable = false)
    private String imageUrl;

    /** 썸네일 이미지 URL (nullable) */
    private String thumbnailUrl;

    /** 연계 동영상 URL (nullable) */
    private String videoUrl;

    /** 촬영 일시(선택) */
    private LocalDateTime takenAt;

    /** 위치 ID(선택) */
    private Long locationId;

    /** 브랜드/부스 이름(선택, 예: 인생네컷, 하유두유두 등) */
    private String brand;

    /** QR 페이로드 해시(중복 방지용) */
    @Column(unique = true)
    private String qrHash;

    /** 생성 시각 */
    private LocalDateTime createdAt = LocalDateTime.now();

    /** 소프트 삭제 플래그 */
    private Boolean deleted = false;

    public Photo() {}

    public Photo(Long userId, Album album,
                 String imageUrl, String thumbnailUrl, String videoUrl,
                 String qrHash, String brand, LocalDateTime takenAt, Long locationId) {
        this.userId = userId;
        this.album = album;
        this.imageUrl = imageUrl;
        this.thumbnailUrl = thumbnailUrl;
        this.videoUrl = videoUrl;
        this.qrHash = qrHash;
        this.brand = brand;
        this.takenAt = takenAt;
        this.locationId = locationId;
    }

    // --- getters/setters ---
    public Long getId() { return id; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public Album getAlbum() { return album; }
    public void setAlbum(Album album) { this.album = album; }
    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
    public String getThumbnailUrl() { return thumbnailUrl; }
    public void setThumbnailUrl(String thumbnailUrl) { this.thumbnailUrl = thumbnailUrl; }
    public String getVideoUrl() { return videoUrl; }
    public void setVideoUrl(String videoUrl) { this.videoUrl = videoUrl; }
    public LocalDateTime getTakenAt() { return takenAt; }
    public void setTakenAt(LocalDateTime takenAt) { this.takenAt = takenAt; }
    public Long getLocationId() { return locationId; }
    public void setLocationId(Long locationId) { this.locationId = locationId; }
    public String getBrand() { return brand; }
    public void setBrand(String brand) { this.brand = brand; }
    public String getQrHash() { return qrHash; }
    public void setQrHash(String qrHash) { this.qrHash = qrHash; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public Boolean getDeleted() { return deleted; }
    public void setDeleted(Boolean deleted) { this.deleted = deleted; }
}
