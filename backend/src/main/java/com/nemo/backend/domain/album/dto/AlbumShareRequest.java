package com.nemo.backend.domain.album.dto;

import com.nemo.backend.domain.album.entity.AlbumShare.Role;

import java.util.List;

/**
 * 앨범 공유 요청 DTO
 */
public record AlbumShareRequest(
        List<Long> friendIdList,   // 공유할 친구 userId 목록
        Role defaultRole           // 기본 권한 (없으면 VIEWER)
) {
}
