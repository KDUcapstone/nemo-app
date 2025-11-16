package com.nemo.backend.domain.album.dto;

import java.util.List;
import lombok.Builder;

@Builder
public record AlbumShareResponse(
        Long albumId,
        List<SharedUser> sharedTo,
        String message
) {
    @Builder
    public record SharedUser(
            Long userId,
            String nickname
    ) {}
}
