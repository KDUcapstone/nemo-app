// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumCreatedResponse.java
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
public class AlbumCreatedResponse {

    private Long albumId;
    private String title;
    private String description;
    private String coverPhotoUrl;
    private int photoCount;
    private LocalDateTime createdAt;

    public static AlbumCreatedResponse from(AlbumDetailResponse detail) {
        return AlbumCreatedResponse.builder()
                .albumId(detail.getAlbumId())
                .title(detail.getTitle())
                .description(detail.getDescription())
                .coverPhotoUrl(detail.getCoverPhotoUrl())
                .photoCount(detail.getPhotoCount())
                .createdAt(detail.getCreatedAt())
                .build();
    }
}
