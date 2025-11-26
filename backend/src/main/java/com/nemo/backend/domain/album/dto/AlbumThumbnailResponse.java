// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumThumbnailResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 썸네일 지정 응답
 * 명세: albumId, thumbnailUrl, message
 */
@Getter
@AllArgsConstructor
public class AlbumThumbnailResponse {
    private Long albumId;
    private String thumbnailUrl;
    private String message;
}
