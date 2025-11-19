package com.nemo.backend.domain.friend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 친구 요청 보내기 RequestBody
 * {
 *   "targetUserId": 3
 * }
 */
@Getter
@NoArgsConstructor
@Schema(description = "친구 요청 보내기 요청 바디")
public class FriendAddRequest {

    @Schema(description = "친구 요청을 보낼 대상 사용자 ID", example = "3")
    private Long targetUserId;
}
