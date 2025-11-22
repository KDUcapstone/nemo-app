// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumCreatedResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

/**
 * 앨범 생성 응답 (201)
 * 명세: albumId, title, description, coverPhotoUrl, photoCount, createdAt
 */
@Getter
@Builder
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
