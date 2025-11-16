package com.nemo.backend.domain.album.dto;

import java.util.List;
import lombok.Builder;

/**
 * 특정 앨범에 공유된 사용자 목록
 */
@Builder
public record AlbumShareTargetsResponse(
        Long albumId,
        List<AlbumShareResponse.SharedUser> sharedTo
) {
}
