// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumShareResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

/**
 * 앨범 공유 응답
 * 명세: albumId, sharedTo[], message
 */
@Getter
@Builder
public class AlbumShareResponse {

    private Long albumId;
    private List<SharedTarget> sharedTo;
    private String message;

    @Getter
    @Builder
    public static class SharedTarget {
        private Long userId;
        private String nickname;
    }

    @Getter
    @Builder
    public static class SharedUser {
        private Long userId;
        private String nickname;
        private String role; // OWNER / CO_OWNER / EDITOR / VIEWER
    }
}
