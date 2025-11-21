package com.nemo.backend.domain.notification.dto;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class NotificationGroupResponse {
    private String label;                      // "오늘", "최근 7일", "이전"
    private List<NotificationItemResponse> items;
}
