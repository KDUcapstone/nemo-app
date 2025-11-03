// backend/src/main/java/com/nemo/backend/domain/album/dto/UpdateAlbumRequest.java
package com.nemo.backend.domain.album.dto;

/**
 * 앨범 수정 요청 DTO. 모두 선택.
 */
public class UpdateAlbumRequest {
    private String title;
    private String description;
    private Long coverPhotoId;

    public UpdateAlbumRequest() {}

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Long getCoverPhotoId() { return coverPhotoId; }
    public void setCoverPhotoId(Long coverPhotoId) { this.coverPhotoId = coverPhotoId; }
}
