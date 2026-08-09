// com.nemo.backend.domain.album.dto.AlbumDownloadUrlsResponse
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
public class AlbumDownloadUrlsResponse {
    private Long albumId;
    private String albumTitle;
    private Integer photoCount;
    private List<AlbumPhotoDownloadUrlDto> photos;
}
