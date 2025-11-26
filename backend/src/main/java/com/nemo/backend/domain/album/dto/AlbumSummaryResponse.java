// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumSummaryResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

/**
 * 앨범 목록 조회 항목
 * 명세: albumId, title, coverPhotoUrl, photoCount, createdAt, role
 */
@Getter
@Builder
public class AlbumSummaryResponse {

    private Long albumId;
    private String title;
    private String coverPhotoUrl;
    private int photoCount;
    private LocalDateTime createdAt;
    private String role;   // OWNER / CO_OWNER / EDITOR / VIEWER
}
