package com.nemo.backend.domain.notification.dto;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class NotificationListResponse {

    private Summary summary;  // 상단 unreadCount

    private List<NotificationGroupResponse> groups;

    private PageInfo page;    // 페이지 정보 (현재는 단순 고정)

    @Data
    @Builder
    public static class Summary {
        private long unreadCount;
    }

    @Data
    @Builder
    public static class PageInfo {
        private int size;
        private long totalElements;
        private int totalPages;
        private int number;
    }
}
