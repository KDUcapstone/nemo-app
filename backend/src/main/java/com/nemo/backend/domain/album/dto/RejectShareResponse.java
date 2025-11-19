// backend/src/main/java/com/nemo/backend/domain/album/dto/RejectShareResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 공유 거절 응답
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RejectShareResponse {

    private Long albumId;
    private String message;
}
