// backend/src/main/java/com/nemo/backend/domain/album/dto/UpdateSharePermissionRequest.java
package com.nemo.backend.domain.album.dto;

import com.nemo.backend.domain.album.entity.AlbumShare;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 공유 멤버 권한 변경 요청
 * 명세: targetUserId, role
 */
@Getter
@Setter
@NoArgsConstructor
public class UpdateSharePermissionRequest {

    private Long targetUserId;
    private AlbumShare.Role role;  // JSON: "VIEWER" / "EDITOR" / "CO_OWNER"
}
