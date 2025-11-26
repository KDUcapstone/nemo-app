// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumShareLinkResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 공유 링크 생성 응답
 * 명세: albumId, shareUrl
 */
@Getter
@AllArgsConstructor
public class AlbumShareLinkResponse {
    private Long albumId;
    private String shareUrl;
}
