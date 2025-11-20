package com.nemo.backend.domain.album.dto;

import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.entity.AlbumShare;
import lombok.Builder;

import java.time.LocalDateTime;

/**
 * "내가 공유받은 앨범" 목록용 DTO
 */
@Builder
public record SharedAlbumSummaryResponse(
        Long albumId,
        String title,
        String description,
        String coverPhotoUrl,
        Long ownerId,
        String ownerNickname,
        AlbumShare.Role myRole,
        LocalDateTime sharedAt,
        int photoCount
) {
    public static SharedAlbumSummaryResponse from(Album album,
                                                  AlbumShare share,
                                                  String resolvedCoverUrl,
                                                  int photoCount) {
        return SharedAlbumSummaryResponse.builder()
                .albumId(album.getId())
                .title(album.getName())
                .description(album.getDescription())
                .coverPhotoUrl(resolvedCoverUrl)
                .ownerId(album.getUser().getId())
                .ownerNickname(album.getUser().getNickname())
                .myRole(share.getRole())
                .sharedAt(share.getCreatedAt())
                .photoCount(photoCount)
                .build();
    }
}
