package com.nemo.backend.domain.album.dto;

import lombok.Data;

@Data
public class AlbumCreateRequest {
    private Long userId;
    private String name;
    private String description;
}
