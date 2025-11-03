package com.nemo.backend.domain.friend.controller;

import com.nemo.backend.domain.friend.service.FriendService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * FriendController
 * -------------------------------------
 * 친구 관련 API 요청을 처리하는 컨트롤러
 * (요청 → Service → Repository 순으로 동작)
 *
 * 엔드포인트 예시:
 *  - POST   /api/friends           → 친구 요청 보내기
 *  - GET    /api/friends           → 친구 목록 조회
 *  - PUT    /api/friends/accept    → 친구 요청 수락
 *  - DELETE /api/friends/{id}      → 친구 삭제
 */
@RestController
@RequestMapping("/api/friends")
@RequiredArgsConstructor
public class FriendController {

    private final FriendService friendService;

    /**
     * ✅ 친구 요청 보내기
     * ------------------------------
     * [POST] /api/friends
     * Body 또는 Query로 meId, targetId를 전달받음
     * ex) /api/friends?meId=1&targetId=2
     */
    @PostMapping
    public ResponseEntity<?> addFriend(
            @RequestParam Long meId,
            @RequestParam Long targetId
    ) {
        friendService.sendFriendRequest(meId, targetId);
        return ResponseEntity.ok(Map.of(
                "message", "친구 요청이 성공적으로 전송되었습니다.",
                "targetUserId", targetId
        ));
    }

    /**
     * ✅ 친구 목록 조회
     * ------------------------------
     * [GET] /api/friends
     * ex) /api/friends?meId=1
     *
     * 나(meId)의 친구 중 상태가 ACCEPTED인 친구 리스트 반환
     */
    @GetMapping
    public ResponseEntity<?> getFriends(
            @RequestParam Long meId
    ) {
        return ResponseEntity.ok(friendService.getFriendList(meId));
    }

    /**
     * ✅ 친구 요청 수락
     * ------------------------------
     * [PUT] /api/friends/accept
     * ex) /api/friends/accept?userId=2&requesterId=1
     *
     * userId: 수락하는 사람
     * requesterId: 친구 요청을 보낸 사람
     */
    @PutMapping("/accept")
    public ResponseEntity<?> acceptFriend(
            @RequestParam Long userId,
            @RequestParam Long requesterId
    ) {
        friendService.acceptFriend(userId, requesterId);
        return ResponseEntity.ok(Map.of(
                "message", "친구 요청이 수락되었습니다.",
                "acceptedUserId", requesterId
        ));
    }

    /**
     * ✅ 친구 삭제
     * ------------------------------
     * [DELETE] /api/friends/{friendId}
     * ex) /api/friends/5?meId=1
     *
     * 나(meId)가 특정 친구(friendId) 관계를 삭제
     */
    @DeleteMapping("/{friendId}")
    public ResponseEntity<?> deleteFriend(
            @RequestParam Long meId,
            @PathVariable Long friendId
    ) {
        friendService.deleteFriend(meId, friendId);
        return ResponseEntity.ok(Map.of(
                "message", "친구가 성공적으로 삭제되었습니다.",
                "deletedFriendId", friendId
        ));
    }
}

