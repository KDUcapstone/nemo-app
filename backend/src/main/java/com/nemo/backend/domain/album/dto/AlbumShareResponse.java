package com.nemo.backend.domain.album.dto;

import com.nemo.backend.domain.album.entity.AlbumShare;
import lombok.Builder;

import java.time.LocalDateTime;
import java.util.List;

@Builder
public record AlbumShareResponse(
        Long albumId,
        List<SharedUser> sharedTo,
        String message
) {

    @Builder
    public record SharedUser(
            Long shareId,
            Long userId,
            String nickname,
            String email,
            AlbumShare.Role role,
            AlbumShare.Status status,
            LocalDateTime invitedAt
    ) {}
}
