package com.nemo.backend.domain.album.dto;

/**
 * 앨범 공유 링크 응답
 */
public record AlbumShareLinkResponse(
        Long albumId,
        String shareUrl
) {
}
