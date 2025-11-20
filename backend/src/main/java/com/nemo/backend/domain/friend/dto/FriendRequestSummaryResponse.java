package com.nemo.backend.domain.friend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

/**
 * 친구 요청 목록 조회용 DTO (한 건)
 * 명세서 예시:
 * {
 *   "requestId": 12,
 *   "userId": 4,
 *   "nickname": "포토러버",
 *   "email": "lover@nemo.com",
 *   "profileImageUrl": "...",
 *   "requestedAt": "2025-07-21T13:20:00"
 * }
 */
@Getter
@Builder
@Schema(description = "나에게 온 친구 요청 한 건에 대한 정보")
public class FriendRequestSummaryResponse {

    @Schema(description = "친구 요청 ID", example = "12")
    private Long requestId;

    @Schema(description = "친구 요청을 보낸 사용자 ID", example = "4")
    private Long userId;

    @Schema(description = "요청 보낸 사용자 닉네임", example = "포토러버")
    private String nickname;

    @Schema(description = "요청 보낸 사용자 이메일", example = "lover@nemo.com")
    private String email;

    @Schema(description = "요청 보낸 사용자 프로필 이미지 URL", example = "https://cdn.nemo.app/profile/u4.png")
    private String profileImageUrl;

    @Schema(description = "친구 요청 시각(ISO 8601 문자열)", example = "2025-07-21T13:20:00")
    private String requestedAt; // ISO 8601 문자열로 처리
}
