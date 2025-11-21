// backend/src/main/java/com/nemo/backend/domain/album/dto/UpdateSharePermissionResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.Builder;
import lombok.Getter;

/**
 * 공유 멤버 권한 변경 응답
 * 명세: albumId, targetUserId, role, message
 */
@Getter
@Builder
public class UpdateSharePermissionResponse {

    private Long albumId;
    private Long targetUserId;
    private String role;
    private String message;
}
