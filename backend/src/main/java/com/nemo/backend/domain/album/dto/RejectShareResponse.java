// backend/src/main/java/com/nemo/backend/domain/album/dto/RejectShareResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

/**
 * 공유 거절 응답
 * 명세: albumId, message
 */
@Getter
@Builder
public class RejectShareResponse {

    private Long albumId;
    private String message;
}
