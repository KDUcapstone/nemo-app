package com.nemo.backend.domain.friend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;

/**
 * 친구 목록 조회용 DTO
 * --------------------------------
 * - 이미 친구 관계인 사용자만 조회할 때 사용
 * - 친구 여부(isFriend)는 불필요
 */
@Data
@AllArgsConstructor
@Builder
public class FriendListResponse {
    private Long userId;
    private String nickname;
    private String email;
    private String profileImageUrl;
}
