// domain/friend/controller/FriendController.java
package com.nemo.backend.domain.friend.controller;

import com.nemo.backend.domain.auth.principal.UserPrincipal;
import com.nemo.backend.domain.friend.dto.FriendSearchResponse;
import com.nemo.backend.domain.friend.service.FriendService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * ✅ 친구 API 컨트롤러
 * - @AuthenticationPrincipal UserPrincipal me 로 "현재 로그인 사용자"를 자동 주입
 * - 더 이상 @RequestParam meId 필요 없음
 */
@RestController
@RequestMapping("/api/friends")
@RequiredArgsConstructor
public class FriendController {

    private final FriendService friendService;

    /** 친구 검색: 닉네임/이메일 일부로 검색, 검색 결과에 isFriend 포함 */
    @GetMapping("/search")
    public ResponseEntity<List<FriendSearchResponse>> searchFriends(
            @AuthenticationPrincipal UserPrincipal me,   // ← JWT에서 추출된 나의 정보
            @RequestParam String keyword
    ) {
        return ResponseEntity.ok(friendService.searchFriends(me.getId(), keyword));
    }

    /** 친구 요청: 나(me) → targetId */
    @PostMapping
    public ResponseEntity<?> addFriend(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam Long targetId
    ) {
        friendService.sendFriendRequest(me.getId(), targetId);
        return ResponseEntity.ok(Map.of(
                "message", "친구 요청이 성공적으로 전송되었습니다.",
                "targetUserId", targetId
        ));
    }

    /** 친구 목록: 이미 친구(ACCEPTED)인 사용자 목록 반환 (DTO 권장) */
    @GetMapping
    public ResponseEntity<?> getFriends(@AuthenticationPrincipal UserPrincipal me) {
        return ResponseEntity.ok(friendService.getFriendList(me.getId()));
    }

    /** 친구 수락: 요청 보낸 사람(requesterId)을 내가(me) 수락 */
    @PutMapping("/accept")
    public ResponseEntity<?> acceptFriend(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam Long requesterId
    ) {
        friendService.acceptFriend(me.getId(), requesterId);
        return ResponseEntity.ok(Map.of(
                "message", "친구 요청이 수락되었습니다.",
                "acceptedUserId", requesterId
        ));
    }

    /** 친구 삭제: 나(me) 기준으로 특정 friendId와의 관계 끊기 */
    @DeleteMapping("/{friendId}")
    public ResponseEntity<?> deleteFriend(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable Long friendId
    ) {
        friendService.deleteFriend(me.getId(), friendId);
        return ResponseEntity.ok(Map.of(
                "message", "친구가 성공적으로 삭제되었습니다.",
                "deletedFriendId", friendId
        ));
    }
}
