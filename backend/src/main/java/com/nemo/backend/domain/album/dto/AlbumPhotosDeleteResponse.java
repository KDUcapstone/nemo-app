// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumPhotosDeleteResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

/**
 * 앨범 사진 삭제 응답
 * 명세: albumId, deletedCount, message
 */
@Getter
@Builder
public class AlbumPhotosDeleteResponse {
    private Long albumId;
    private int deletedCount;
    private String message;
}
