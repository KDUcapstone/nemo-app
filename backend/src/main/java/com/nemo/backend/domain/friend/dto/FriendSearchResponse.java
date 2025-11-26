package com.nemo.backend.domain.friend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
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
@Schema(description = "친구 검색 결과(사용자 한 명 정보)")
public class FriendSearchResponse {

    @Schema(description = "사용자 ID", example = "2")
    private Long userId;           // 사용자 ID

    @Schema(description = "닉네임", example = "네컷매니아")
    private String nickname;       // 닉네임

    @Schema(description = "이메일", example = "fourcut@example.com")
    private String email;          // 이메일

    @Schema(description = "프로필 이미지 URL", example = "https://cdn.nemo.app/profile/user2.png")
    private String profileImageUrl;// 프로필 이미지

    @Schema(description = "이미 친구인지 여부", example = "true")
    private boolean isFriend;      // 이미 친구인지 여부
}
