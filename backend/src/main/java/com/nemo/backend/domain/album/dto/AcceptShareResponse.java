// backend/src/main/java/com/nemo/backend/domain/album/dto/AcceptShareResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

/**
 * 공유 수락 응답
 * 명세: albumId, role, message
 */
@Getter
@Builder
public class AcceptShareResponse {

    private Long albumId;
    private String role;
    private String message;
}
