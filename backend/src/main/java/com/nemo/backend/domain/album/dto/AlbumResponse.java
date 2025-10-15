package com.nemo.backend.domain.album.dto;

import com.nemo.backend.domain.album.entity.Album;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class AlbumResponse {
    private Long id;
    private String name;
    private String description;
    private Long userId;

    public static AlbumResponse fromEntity(Album album) {
        return new AlbumResponse(
                album.getId(),
                album.getName(),
                album.getDescription(),
                album.getUser() != null ? album.getUser().getId() : null
        );
    }
}
