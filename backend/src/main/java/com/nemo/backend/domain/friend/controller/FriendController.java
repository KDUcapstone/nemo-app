// domain/friend/controller/FriendController.java
package com.nemo.backend.domain.friend.controller;

import com.nemo.backend.domain.auth.principal.UserPrincipal;
import com.nemo.backend.domain.friend.dto.*;
import com.nemo.backend.domain.friend.service.FriendService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.parameters.RequestBody;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * ✅ 친구 API 컨트롤러 (API 명세서 기준)
 */
@Tag(name = "Friend", description = "친구 검색 · 요청 · 수락 · 거절 · 목록 · 삭제 API")
@RestController
@RequestMapping(value ="/api/friends",
        produces = "application/json; charset=UTF-8")
@RequiredArgsConstructor
public class FriendController {

    private final FriendService friendService;

    // --------------------------------------------------------------------
    // 1. 친구 검색: GET /api/friends/search?keyword=...
    // --------------------------------------------------------------------

    @Operation(
            summary = "친구 검색",
            description = "닉네임 또는 이메일 일부로 사용자를 검색합니다. (자기 자신은 결과에서 제외)"
    )
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "검색 성공",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = FriendSearchResponse.class))),
            @ApiResponse(responseCode = "401", description = "인증 필요")
    })
    @GetMapping("/search")
    public ResponseEntity<List<FriendSearchResponse>> searchFriends(
            @AuthenticationPrincipal UserPrincipal me,
            @Parameter(description = "검색어 (닉네임 또는 이메일 일부)", example = "네컷")
            @RequestParam String keyword
    ) {
        List<FriendSearchResponse> result = friendService.searchFriends(me.getId(), keyword);
        return ResponseEntity.ok(result);
    }

    // --------------------------------------------------------------------
    // 2. 친구 요청 보내기: POST /api/friends
    //    Body: { "targetUserId": 3 }
    // --------------------------------------------------------------------

    @Operation(
            summary = "친구 요청 보내기",
            description = "다른 사용자에게 친구 요청을 보냅니다. (status=PENDING)"
    )
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "친구 요청 전송 성공",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = FriendAddResponse.class))),
            @ApiResponse(responseCode = "400", description = "자기 자신에게 요청, 잘못된 요청"),
            @ApiResponse(responseCode = "409", description = "이미 친구이거나 요청 중인 상태"),
            @ApiResponse(responseCode = "401", description = "인증 필요")
    })
    @PostMapping
    public ResponseEntity<FriendAddResponse> addFriend(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestBody(
                    description = "친구 요청 대상 사용자 ID",
                    required = true,
                    content = @Content(schema = @Schema(implementation = FriendAddRequest.class))
            )
            @org.springframework.web.bind.annotation.RequestBody FriendAddRequest request
    ) {
        FriendAddResponse response =
                friendService.sendFriendRequest(me.getId(), request.getTargetUserId());

        // 명세서: 201 Created
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }

    // --------------------------------------------------------------------
    // 3. 친구 목록 조회: GET /api/friends
    // --------------------------------------------------------------------

    @Operation(
            summary = "친구 목록 조회",
            description = "현재 로그인한 사용자의 친구 목록(ACCEPTED)을 조회합니다."
    )
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = FriendListResponse.class))),
            @ApiResponse(responseCode = "401", description = "인증 필요")
    })
    @GetMapping
    public ResponseEntity<List<FriendListResponse>> getFriends(
            @AuthenticationPrincipal UserPrincipal me
    ) {
        List<FriendListResponse> friends = friendService.getFriendList(me.getId());
        return ResponseEntity.ok(friends);
    }

    // --------------------------------------------------------------------
    // 4. 친구 삭제: DELETE /api/friends/{friendId}
    // --------------------------------------------------------------------

    @Operation(
            summary = "친구 삭제",
            description = "친구 목록에서 특정 사용자를 삭제합니다. (친구 관계를 양방향으로 제거)"
    )
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "삭제 완료",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = FriendDeleteResponse.class))),
            @ApiResponse(responseCode = "400", description = "해당 사용자는 친구가 아님"),
            @ApiResponse(responseCode = "401", description = "인증 필요")
    })
    @DeleteMapping("/{friendId}")
    public ResponseEntity<FriendDeleteResponse> deleteFriend(
            @AuthenticationPrincipal UserPrincipal me,
            @Parameter(description = "삭제할 친구의 사용자 ID", example = "5")
            @PathVariable Long friendId
    ) {
        FriendDeleteResponse response = friendService.deleteFriend(me.getId(), friendId);
        return ResponseEntity.ok(response);
    }

    // --------------------------------------------------------------------
    // 5. 나에게 온 친구 요청 목록: GET /api/friends/requests
    // --------------------------------------------------------------------

    @Operation(
            summary = "친구 요청 목록 조회",
            description = "나에게 도착한 친구 요청 목록(PENDING 상태)을 조회합니다."
    )
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = FriendRequestSummaryResponse.class))),
            @ApiResponse(responseCode = "401", description = "인증 필요")
    })
    @GetMapping("/requests")
    public ResponseEntity<List<FriendRequestSummaryResponse>> getFriendRequests(
            @AuthenticationPrincipal UserPrincipal me
    ) {
        List<FriendRequestSummaryResponse> requests =
                friendService.getIncomingRequests(me.getId());
        return ResponseEntity.ok(requests);
    }

    // --------------------------------------------------------------------
    // 6. 친구 요청 수락: POST /api/friends/{requestId}/accept
    // --------------------------------------------------------------------

    @Operation(
            summary = "친구 요청 수락",
            description = "나에게 도착한 친구 요청을 수락하여 친구 상태로 만듭니다."
    )
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "수락 성공",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = FriendRequestAcceptResponse.class))),
            @ApiResponse(responseCode = "404", description = "요청이 존재하지 않음"),
            @ApiResponse(responseCode = "403", description = "내 요청이 아님 (권한 없음)"),
            @ApiResponse(responseCode = "401", description = "인증 필요")
    })
    @PostMapping("/{requestId}/accept")
    public ResponseEntity<FriendRequestAcceptResponse> acceptFriendRequest(
            @AuthenticationPrincipal UserPrincipal me,
            @Parameter(description = "친구 요청 ID (Friend 엔티티 PK)", example = "12")
            @PathVariable Long requestId
    ) {
        FriendRequestAcceptResponse response =
                friendService.acceptFriendRequest(me.getId(), requestId);
        return ResponseEntity.ok(response);
    }

    // --------------------------------------------------------------------
    // 7. 친구 요청 거절: POST /api/friends/{requestId}/reject
    // --------------------------------------------------------------------

    @Operation(
            summary = "친구 요청 거절",
            description = "나에게 도착한 친구 요청을 거절합니다. (현재는 요청 row 삭제 방식)"
    )
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "거절 성공",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = FriendRequestRejectResponse.class))),
            @ApiResponse(responseCode = "404", description = "요청이 존재하지 않음"),
            @ApiResponse(responseCode = "403", description = "내 요청이 아님 (권한 없음)"),
            @ApiResponse(responseCode = "401", description = "인증 필요")
    })
    @PostMapping("/{requestId}/reject")
    public ResponseEntity<FriendRequestRejectResponse> rejectFriendRequest(
            @AuthenticationPrincipal UserPrincipal me,
            @Parameter(description = "친구 요청 ID (Friend 엔티티 PK)", example = "12")
            @PathVariable Long requestId
    ) {
        FriendRequestRejectResponse response =
                friendService.rejectFriendRequest(me.getId(), requestId);
        return ResponseEntity.ok(response);
    }
}
