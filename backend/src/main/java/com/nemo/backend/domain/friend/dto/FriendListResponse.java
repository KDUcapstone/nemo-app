package com.nemo.backend.domain.friend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
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
@Schema(description = "친구 목록 조회 응답(친구 한 명 정보)")
public class FriendListResponse {

    @Schema(description = "친구 사용자 ID", example = "3")
    private Long userId;

    @Schema(description = "친구 닉네임", example = "네컷러버")
    private String nickname;

    @Schema(description = "친구 이메일", example = "friend1@example.com")
    private String email;

    @Schema(description = "친구 프로필 이미지 URL", example = "https://cdn.nemo.app/profile/user3.png")
    private String profileImageUrl;
}
