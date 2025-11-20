package com.nemo.backend.domain.album.dto;

import com.nemo.backend.domain.album.entity.AlbumShare;

/**
 * 공유 멤버 권한 변경 API 요청 DTO
 * - PUT /api/albums/{albumId}/share/permission
 */
public record UpdateSharePermissionRequest(
        Long targetUserId,          // 권한을 변경할 사용자 ID
        AlbumShare.Role role        // 새 권한 (VIEWER / EDITOR / CO_OWNER)
) {
}
