// backend/src/main/java/com/nemo/backend/domain/album/dto/UnshareResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

/**
 * 공유 멤버 제거 응답
 * 명세: albumId, removedUserId, message
 */
@Getter
@Builder
public class UnshareResponse {

    private Long albumId;
    private Long removedUserId;
    private String message;
}
