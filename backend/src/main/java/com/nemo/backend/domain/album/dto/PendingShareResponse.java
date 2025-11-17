package com.nemo.backend.domain.album.dto;

import com.nemo.backend.domain.album.entity.AlbumShare;
import lombok.Builder;

import java.time.LocalDateTime;

/**
 * "내가 공유 받기 대기 중(PENDING)"인 앨범 정보
 */
@Builder
public record PendingShareResponse(
        Long shareId,
        Long albumId,
        String albumTitle,
        Long ownerId,
        String ownerNickname,
        AlbumShare.Role role,
        LocalDateTime invitedAt
) {
    public static PendingShareResponse from(AlbumShare share) {
        return PendingShareResponse.builder()
                .shareId(share.getId())
                .albumId(share.getAlbum().getId())
                .albumTitle(share.getAlbum().getName())
                .ownerId(share.getAlbum().getUser().getId())
                .ownerNickname(share.getAlbum().getUser().getNickname())
                .role(share.getRole())
                .invitedAt(share.getCreatedAt())
                .build();
    }
}
