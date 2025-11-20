// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumThumbnailResponse.java
package com.nemo.backend.domain.album.dto;

public class AlbumThumbnailResponse {

    private Long albumId;
    private String thumbnailUrl;
    private String message;

    public AlbumThumbnailResponse(Long albumId, String thumbnailUrl, String message) {
        this.albumId = albumId;
        this.thumbnailUrl = thumbnailUrl;
        this.message = message;
    }

    public Long getAlbumId() { return albumId; }
    public String getThumbnailUrl() { return thumbnailUrl; }
    public String getMessage() { return message; }
}
