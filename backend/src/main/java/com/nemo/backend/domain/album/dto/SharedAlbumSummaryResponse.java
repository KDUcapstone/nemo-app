// backend/src/main/java/com/nemo/backend/domain/album/dto/SharedAlbumSummaryResponse.java
package com.nemo.backend.domain.album.dto;

import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.entity.AlbumShare;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

/**
 * 내가 공유받은 앨범 목록 응답 항목
 * (명세에는 상세히 안나와서, 일반 목록 요약 + role만 포함)
 */
@Getter
@Builder
public class SharedAlbumSummaryResponse {

    private Long albumId;
    private String title;
    private String coverPhotoUrl;
    private int photoCount;
    private LocalDateTime createdAt;
    private String role;

    public static SharedAlbumSummaryResponse from(
            Album album,
            AlbumShare share,
            String coverUrl,
            int photoCount
    ) {
        return SharedAlbumSummaryResponse.builder()
                .albumId(album.getId())
                .title(album.getName())
                .coverPhotoUrl(coverUrl)
                .photoCount(photoCount)
                .createdAt(album.getCreatedAt())
                .role(share.getRole().name())
                .build();
    }
}
