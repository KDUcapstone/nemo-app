// backend/src/main/java/com/nemo/backend/domain/album/dto/UpdateSharePermissionResponse.java
package com.nemo.backend.domain.album.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 공유 멤버 권한 변경 응답
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdateSharePermissionResponse {

    private Long albumId;
    private Long targetUserId;
    private String role;   // VIEWER / EDITOR / CO_OWNER
    private String message;
}
