package com.nemo.backend.domain.album.dto;

import com.nemo.backend.domain.album.entity.AlbumShare;
import lombok.Builder;

@Builder
public record AlbumShareResponse(
        Long albumId,
        String message
) {
    @Builder
    public record SharedUser(
            Long userId,
            String nickname,
            AlbumShare.Role role
    ) {}
}
