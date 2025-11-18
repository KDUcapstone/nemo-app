// com.nemo.backend.domain.photo.entity.Photo
package com.nemo.backend.domain.photo.entity;

import com.nemo.backend.domain.album.entity.Album;
import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 사진 1장(레코드) + 연계 동영상 URL을 함께 저장하기 위한 엔티티.
 * QR 해시(qrHash)로 중복 업로드를 방지한다.
 */
@Entity
@Table(name = "photos", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"qrHash"})
})
public class Photo {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long userId;

    /** 앨범 연관관계로 변경 */
    @ManyToOne(fetch = FetchType.LAZY)
    private Album album;

    @Column(nullable = false)
    private String imageUrl;
    private String thumbnailUrl;
    private String videoUrl;

    private LocalDateTime takenAt;

    /** 장소 ID (추후 Location 엔티티용) */
    private Long locationId;

    /** 장소명(문자열) – 명세서의 location 필드용 */
    @Column(name = "location_name")
    private String locationName;

    private String brand;

    @Column(unique = true)
    private String qrHash;

    /** 즐겨찾기 여부 (기본 false) */
    @Column(name = "favorite")
    private Boolean favorite = false;

    /** 메모(상세 편집에서 사용하는 필드) */
    @Column(name = "memo", length = 300)
    private String memo;

    private LocalDateTime createdAt = LocalDateTime.now();
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

    /** 기존 코드 호환용 편의 메서드 */
    public Long getAlbumId() { return album != null ? album.getId() : null; }

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

    public String getLocationName() { return locationName; }
    public void setLocationName(String locationName) { this.locationName = locationName; }

    public String getBrand() { return brand; }
    public void setBrand(String brand) { this.brand = brand; }

    public String getQrHash() { return qrHash; }
    public void setQrHash(String qrHash) { this.qrHash = qrHash; }

    public Boolean getFavorite() { return favorite; }
    public void setFavorite(Boolean favorite) { this.favorite = favorite; }

    public String getMemo() { return memo; }
    public void setMemo(String memo) { this.memo = memo; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public Boolean getDeleted() { return deleted; }
    public void setDeleted(Boolean deleted) { this.deleted = deleted; }
}
