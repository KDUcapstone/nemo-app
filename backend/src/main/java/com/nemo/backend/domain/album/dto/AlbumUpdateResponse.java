// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumUpdateResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

/**
 * 앨범 수정 응답
 * 명세: albumId, message
 */
@Getter
@Builder
public class AlbumUpdateResponse {
    private Long albumId;
    private String message;
}
