package com.nemo.backend.domain.friend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

/**
 * 친구 요청 수락 응답 DTO
 * {
 *   "requestId": 12,
 *   "friendUserId": 4,
 *   "nickname": "포토러버",
 *   "message": "친구 요청이 성공적으로 수락되었습니다."
 * }
 */
@Getter
@Builder
@Schema(description = "친구 요청 수락 응답")
public class FriendRequestAcceptResponse {

    @Schema(description = "수락한 친구 요청 ID", example = "12")
    private Long requestId;

    @Schema(description = "친구가 된 사용자 ID", example = "4")
    private Long friendUserId;

    @Schema(description = "친구 닉네임", example = "포토러버")
    private String nickname;

    @Schema(description = "결과 메시지", example = "친구 요청이 성공적으로 수락되었습니다.")
    private String message;
}
