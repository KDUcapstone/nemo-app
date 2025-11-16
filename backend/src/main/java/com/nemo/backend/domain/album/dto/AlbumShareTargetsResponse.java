package com.nemo.backend.domain.album.dto;

import java.util.List;
import lombok.Builder;

@Builder
public record AlbumShareTargetsResponse(
        List<AlbumShareResponse.SharedUser> sharedTo
) {}
