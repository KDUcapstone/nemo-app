// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumThumbnailSelectRequest.java
package com.nemo.backend.domain.album.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 썸네일 선택(JSON) 요청
 * 명세: { "photoId": number }
 */
@Getter
@Setter
@NoArgsConstructor
public class AlbumThumbnailSelectRequest {
    private Long photoId;
}
