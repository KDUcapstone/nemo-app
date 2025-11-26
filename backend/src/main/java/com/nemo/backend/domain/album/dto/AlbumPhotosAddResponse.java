// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumPhotosAddResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

/**
 * 앨범 사진 추가 응답
 * 명세: albumId, addedCount, message
 */
@Getter
@Builder
public class AlbumPhotosAddResponse {
    private Long albumId;
    private int addedCount;
    private String message;
}
