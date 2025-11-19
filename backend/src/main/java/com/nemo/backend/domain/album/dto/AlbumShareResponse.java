// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumShareResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 앨범 공유 요청 결과 및 공유 멤버 조회에 사용
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AlbumShareResponse {

    private Long albumId;
    private List<SharedTarget> sharedTo;   // 공유 요청 보낸 대상들
    private String message;

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SharedTarget {
        private Long userId;
        private String nickname;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SharedUser {
        private Long userId;
        private String nickname;
        private String role; // OWNER / CO_OWNER / EDITOR / VIEWER
    }
}
