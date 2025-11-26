// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumDeleteResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

/**
 * 앨범 삭제 응답
 * 명세: albumId, message
 */
@Getter
@Builder
public class AlbumDeleteResponse {
    private Long albumId;
    private String message;
}
