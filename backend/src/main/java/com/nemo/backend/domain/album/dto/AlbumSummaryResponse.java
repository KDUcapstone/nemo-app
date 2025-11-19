// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumSummaryResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AlbumSummaryResponse {

    private Long albumId;
    private String title;
    private String coverPhotoUrl;
    private int photoCount;
    private LocalDateTime createdAt;
    /**
     * OWNER / CO_OWNER / EDITOR / VIEWER
     */
    private String role;
}
