package com.nemo.backend.domain.friend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

/**
 * 친구 요청 거절 응답 DTO
 * {
 *   "requestId": 12,
 *   "message": "친구 요청이 거절되었습니다."
 * }
 */
@Getter
@Builder
@Schema(description = "친구 요청 거절 응답")
public class FriendRequestRejectResponse {

    @Schema(description = "거절한 친구 요청 ID", example = "12")
    private Long requestId;

    @Schema(description = "결과 메시지", example = "친구 요청이 거절되었습니다.")
    private String message;
}
