// backend/src/main/java/com/nemo/backend/domain/album/dto/UnshareResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 공유 멤버 제거(강퇴/나가기) 응답
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UnshareResponse {

    private Long albumId;
    private Long removedUserId;
    private String message;
}
