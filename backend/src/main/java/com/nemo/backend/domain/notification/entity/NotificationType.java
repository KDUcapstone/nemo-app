package com.nemo.backend.domain.notification.entity;

// ✔ 알림의 "종류" (무슨 일 때문에 알림이 생성되었는가?)
public enum NotificationType {
    FRIEND_REQUEST,      // 친구 요청
    FRIEND_ACCEPTED,     // 친구 요청 수락
    PHOTO_TAGGED,        // 사진 태그됨
    ALBUM_INVITE,        // 앨범 초대
    ALBUM_NEW_PHOTO      // 공유 앨범에 새로운 사진 추가됨
}
