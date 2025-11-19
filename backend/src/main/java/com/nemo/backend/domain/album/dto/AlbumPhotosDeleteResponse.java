// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumPhotosDeleteResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AlbumPhotosDeleteResponse {

    private Long albumId;
    private int deletedCount;
    private String message;
}
