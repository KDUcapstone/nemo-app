package com.nemo.backend.domain.notification.entity;

// ✔ 프론트에서 알림 카드를 눌렀을 때 "어떤 화면으로 이동할지" 알려주는 용도
public enum NotificationActionType {
    OPEN_FRIEND_REQUEST,   // 친구 요청 화면으로 이동
    OPEN_PHOTO,            // 사진 상세 페이지로 이동
    OPEN_ALBUM,            // 앨범 상세 페이지로 이동
    OPEN_USER_PROFILE,     // 사용자 프로필로 이동
    NONE                   // 특정 화면 이동 없음
}
