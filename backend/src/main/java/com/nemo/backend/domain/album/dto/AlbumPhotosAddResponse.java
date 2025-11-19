// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumPhotosAddResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AlbumPhotosAddResponse {

    private Long albumId;
    private int addedCount;
    private String message;
}
