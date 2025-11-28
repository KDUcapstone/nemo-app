// com.nemo.backend.domain.photo.dto.SelectedPhotosDownloadUrlsResponse
package com.nemo.backend.domain.photo.dto;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
public class SelectedPhotosDownloadUrlsResponse {
    private List<PhotoDownloadUrlDto> photos;
}
