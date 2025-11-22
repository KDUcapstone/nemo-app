// backend/src/main/java/com/nemo/backend/domain/album/dto/PendingShareResponse.java
package com.nemo.backend.domain.album.dto;

import com.nemo.backend.domain.album.entity.AlbumShare;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

/**
 * 공유 요청 목록 항목
 * 명세: albumId, albumTitle, invitedBy{userId,nickname}, invitedAt, status
 */
@Getter
@Builder
public class PendingShareResponse {

    private Long albumId;
    private String albumTitle;
    private InvitedBy invitedBy;
    private LocalDateTime invitedAt;
    private String status; // PENDING

    @Getter
    @Builder
    public static class InvitedBy {
        private Long userId;
        private String nickname;
    }

    public static PendingShareResponse from(AlbumShare share) {
        return PendingShareResponse.builder()
                .albumId(share.getAlbum().getId())
                .albumTitle(share.getAlbum().getName())
                .invitedBy(
                        InvitedBy.builder()
                                .userId(share.getAlbum().getUser().getId())
                                .nickname(share.getAlbum().getUser().getNickname())
                                .build()
                )
                .invitedAt(share.getCreatedAt())
                .status(share.getStatus().name())
                .build();
    }
}
