package com.nemo.backend.domain.album.dto;

import java.util.List;

public record AlbumShareRequest(
        List<Long> friendIdList
) {}
