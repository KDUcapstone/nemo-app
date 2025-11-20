package com.nemo.backend.domain.friend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

/**
 * 친구 삭제 응답 DTO
 * {
 *   "message": "친구가 성공적으로 삭제되었습니다.",
 *   "deletedFriendId": 5
 * }
 */
@Getter
@Builder
@Schema(description = "친구 삭제 응답")
public class FriendDeleteResponse {

    @Schema(description = "처리 결과 메시지", example = "친구가 성공적으로 삭제되었습니다.")
    private String message;

    @Schema(description = "삭제된 친구의 사용자 ID", example = "5")
    private Long deletedFriendId;
}
