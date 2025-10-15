package com.nemo.backend.domain.album.dto;

import lombok.Data;

@Data
public class AlbumUpdateRequest {
    private String name;
    private String description;
}
