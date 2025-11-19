package com.nemo.backend.domain.album.dto;

import com.nemo.backend.domain.album.entity.AlbumShare;
import lombok.Builder;

@Builder
public record AcceptShareResponse(
        Long albumId,
        AlbumShare.Role role,
        String message
) {}
