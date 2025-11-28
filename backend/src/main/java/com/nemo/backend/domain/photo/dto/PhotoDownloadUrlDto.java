// com.nemo.backend.domain.photo.dto.PhotoDownloadUrlDto
package com.nemo.backend.domain.photo.dto;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class PhotoDownloadUrlDto {
    private Long photoId;
    private String downloadUrl;
    private String filename;   // 선택
    private Long fileSize;     // 선택 (byte)
}
