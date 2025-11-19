package com.nemo.backend.domain.friend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

/**
 * 친구 요청 보내기 응답 DTO
 * 명세서 예시:
 * {
 *   "requestId": 12,
 *   "status": "PENDING",
 *   "message": "친구 요청이 전송되었습니다.",
 *   "target": {
 *     "userId": 3,
 *     "nickname": "네컷러버",
 *     "profileImageUrl": "..."
 *   }
 * }
 */
@Getter
@Builder
@Schema(description = "친구 요청 보내기 응답")
public class FriendAddResponse {

    @Schema(description = "생성된 친구 요청 ID", example = "12")
    private Long requestId;

    @Schema(description = "요청 상태", example = "PENDING", allowableValues = {"PENDING"})
    private String status;   // "PENDING"

    @Schema(description = "처리 결과 메시지", example = "친구 요청이 전송되었습니다.")
    private String message;

    @Schema(description = "친구 요청 대상 사용자 정보")
    private TargetUser target;

    @Getter
    @Builder
    @Schema(description = "친구 요청 대상 사용자 요약 정보")
    public static class TargetUser {

        @Schema(description = "요청 대상 사용자 ID", example = "3")
        private Long userId;

        @Schema(description = "요청 대상 닉네임", example = "네컷러버")
        private String nickname;

        @Schema(description = "요청 대상 프로필 이미지 URL", example = "https://cdn.nemo.app/profile/user3.png")
        private String profileImageUrl;
    }
}
