package com.nemo.backend.domain.friend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;

/**
 * 친구 검색 결과 DTO
 * -----------------------------------
 * - 닉네임 또는 이메일로 검색한 사용자 정보 반환
 * - 이미 친구인지 여부(isFriend) 포함
 */
@Data
@AllArgsConstructor
@Builder
public class FriendSearchResponse {

    private Long userId;           // 사용자 ID
    private String nickname;       // 닉네임
    private String email;          // 이메일
    private String profileImageUrl;// 프로필 이미지
    private boolean isFriend;      // 이미 친구인지 여부
}
