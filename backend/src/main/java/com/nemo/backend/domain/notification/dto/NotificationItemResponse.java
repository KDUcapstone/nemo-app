package com.nemo.backend.domain.notification.dto;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class NotificationItemResponse {

    private Long notificationId;
    private String type;          // FRIEND_REQUEST, PHOTO_TAGGED …
    private String message;
    private LocalDateTime createdAt;
    private boolean isRead;
    private String actionType;    // OPEN_PHOTO 등

    // ✔ 알림을 발생시킨 사용자 정보
    @Data
    @Builder
    public static class Actor {
        private Long userId;
        private String nickname;
        private String profileImageUrl;
    }
    private Actor actor;

    // ✔ 클릭 시 이동할 대상 정보 (사진/앨범/유저)
    @Data
    @Builder
    public static class Target {
        private String type;   // "PHOTO", "ALBUM", "USER"
        private Long id;
    }
    private Target target;
}
