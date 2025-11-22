// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumFavoriteResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

/**
 * 즐겨찾기 추가/제거 응답
 * 명세: albumId, favorited, message
 */
@Getter
@Builder
public class AlbumFavoriteResponse {
    private Long albumId;
    private boolean favorited;
    private String message;
}
