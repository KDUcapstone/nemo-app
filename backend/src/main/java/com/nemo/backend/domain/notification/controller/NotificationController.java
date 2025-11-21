package com.nemo.backend.domain.notification.controller;

import com.nemo.backend.domain.notification.dto.NotificationListResponse;
import com.nemo.backend.domain.notification.service.NotificationService;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.global.annotation.AuthUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Notification", description = "알림 API")
@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    // ------------------------------------------------------------
    // 📌 알림 목록 조회
    // Swagger UI 에서 바로 테스트하기 좋게 파라미터 설명 추가
    // ------------------------------------------------------------
    @Operation(
            summary = "알림 목록 조회",
            description = "현재 로그인한 사용자에게 온 알림들을 최신순으로 조회합니다. " +
                    "`onlyUnread`에 따라 읽지 않은 알림만 조회할 수 있고, page/size로 페이징 합니다."
    )
    @GetMapping
    public NotificationListResponse getList(
            @AuthUser User user,

            @Parameter(description = "읽지 않은 알림만 조회할지 여부 (true면 미읽음만)", example = "false")
            @RequestParam(name = "onlyUnread", defaultValue = "false") boolean onlyUnread,

            @Parameter(description = "페이지 번호 (0부터 시작)", example = "0")
            @RequestParam(name = "page", defaultValue = "0") int page,

            @Parameter(description = "페이지 크기 (한 페이지 알림 개수)", example = "20")
            @RequestParam(name = "size", defaultValue = "20") int size
    ) {
        return notificationService.getNotifications(user, onlyUnread, page, size);
    }

    // ------------------------------------------------------------
    // 📌 단건 읽음 처리
    // ------------------------------------------------------------
    @Operation(
            summary = "알림 단건 읽음 처리",
            description = "특정 알림을 읽음 상태로 변경합니다."
    )
    @PatchMapping("/{id}/read")
    public void readOne(
            @AuthUser User user,
            @Parameter(description = "읽음 처리할 알림 ID", example = "101")
            @PathVariable("id") Long id
    ) {
        notificationService.readOne(user, id);
    }

    // ------------------------------------------------------------
    // 📌 전체 알림 읽음 처리
    // ------------------------------------------------------------
    @Operation(
            summary = "전체 알림 읽음 처리",
            description = "현재 사용자에게 온 모든 알림을 읽음 상태로 변경합니다."
    )
    @PatchMapping("/read-all")
    public void readAll(@AuthUser User user) {
        notificationService.readAll(user);
    }
}
