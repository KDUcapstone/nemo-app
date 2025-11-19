package com.nemo.backend.domain.friend.entity;

/**
 * 친구 상태를 구분하는 열거형(Enum)
 * ------------------------------
 * - PENDING: 친구 요청을 보낸 상태 (대기중)
 * - ACCEPTED: 친구 요청이 수락된 상태 (서로 친구)
 * - REJECTED: 친구 요청이 거절된 상태 (거절됨)
 */
public enum FriendStatus {
    PENDING,
    ACCEPTED,
    REJECTED
}
