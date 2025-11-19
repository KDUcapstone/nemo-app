// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumShareRequest.java
package com.nemo.backend.domain.album.dto;

import java.util.List;

/**
 * 앨범 공유 요청 DTO (명세서 기준)
 *
 * Request Body 예시:
 * {
 *   "friendIdList": [3, 5]
 * }
 */
public record AlbumShareRequest(
        List<Long> friendIdList   // 공유할 친구 userId 목록
) {
}
