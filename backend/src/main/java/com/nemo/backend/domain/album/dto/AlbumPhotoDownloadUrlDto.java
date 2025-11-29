// com.nemo.backend.domain.album.dto.AlbumPhotoDownloadUrlDto
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class AlbumPhotoDownloadUrlDto {
    private Long photoId;
    private Integer sequence;
    private String downloadUrl;
    private String filename;
    private Long fileSize;
}
