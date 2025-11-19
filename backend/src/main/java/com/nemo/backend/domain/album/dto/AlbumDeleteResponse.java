// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumDeleteResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AlbumDeleteResponse {

    private Long albumId;
    private String message;
}
