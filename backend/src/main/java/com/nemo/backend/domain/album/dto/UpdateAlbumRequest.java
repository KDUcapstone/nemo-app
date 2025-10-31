// backend/src/main/java/com/nemo/backend/domain/album/dto/UpdateAlbumRequest.java
package com.nemo.backend.domain.album.dto;

public class UpdateAlbumRequest {
    private String title;
    private String description;
    private Long coverPhotoId;

    public String getTitle() { return title; }
    public String getDescription() { return description; }
    public Long getCoverPhotoId() { return coverPhotoId; }
}
