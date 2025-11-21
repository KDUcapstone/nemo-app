package com.nemo.backend.domain.notification.service;

import com.nemo.backend.domain.notification.dto.*;
import com.nemo.backend.domain.notification.entity.Notification;
import com.nemo.backend.domain.notification.repository.NotificationRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.global.exception.BaseException;
import com.nemo.backend.global.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;

    // ============================================================
    // 📌 알림 목록 조회 (onlyUnread + pageable)
    // ============================================================
    public NotificationListResponse getNotifications(
            User user,
            boolean onlyUnread,
            int page,
            int size
    ) {
        // 1) Pageable 생성 (createdAt 기준 내림차순)
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));

        // 2) 조건에 따라 전체 / 안 읽은 것만 조회
        Page<Notification> notificationPage = onlyUnread
                ? notificationRepository.findByReceiverAndIsReadFalse(user, pageable)
                : notificationRepository.findByReceiver(user, pageable);

        // 3) 안 읽은 개수(상단 뱃지용)
        long unreadCount = notificationRepository.countByReceiverAndIsReadFalse(user);

        // 4) 그룹핑 (오늘 / 최근 7일 / 이전)
        List<NotificationGroupResponse> groups = group(notificationPage.getContent());

        return NotificationListResponse.builder()
                .summary(NotificationListResponse.Summary.builder()
                        .unreadCount(unreadCount)
                        .build())
                .groups(groups)
                .page(NotificationListResponse.PageInfo.builder()
                        .size(notificationPage.getSize())
                        .totalElements(notificationPage.getTotalElements())
                        .totalPages(notificationPage.getTotalPages())
                        .number(notificationPage.getNumber())
                        .build())
                .build();
    }

    // 📌 그룹핑 로직
    private List<NotificationGroupResponse> group(List<Notification> list) {
        List<NotificationGroupResponse> result = new ArrayList<>();

        LocalDate today = LocalDate.now();
        LocalDate sevenDaysAgo = today.minusDays(7);

        List<NotificationItemResponse> todayList = new ArrayList<>();
        List<NotificationItemResponse> weekList = new ArrayList<>();
        List<NotificationItemResponse> olderList = new ArrayList<>();

        for (Notification n : list) {
            LocalDate d = n.getCreatedAt().toLocalDate();
            NotificationItemResponse dto = toDto(n);

            if (d.isEqual(today)) {
                todayList.add(dto);
            } else if (d.isAfter(sevenDaysAgo)) { // 최근 7일
                weekList.add(dto);
            } else {
                olderList.add(dto);
            }
        }

        if (!todayList.isEmpty())
            result.add(NotificationGroupResponse.builder()
                    .label("오늘")
                    .items(todayList)
                    .build());

        if (!weekList.isEmpty())
            result.add(NotificationGroupResponse.builder()
                    .label("최근 7일")
                    .items(weekList)
                    .build());

        if (!olderList.isEmpty())
            result.add(NotificationGroupResponse.builder()
                    .label("이전")
                    .items(olderList)
                    .build());

        return result;
    }

    // 📌 엔티티 → DTO 변환
    private NotificationItemResponse toDto(Notification n) {
        return NotificationItemResponse.builder()
                .notificationId(n.getId())
                .type(n.getType().name())
                .message(n.getMessage())
                .createdAt(n.getCreatedAt())
                .isRead(n.isRead())
                .actionType(n.getActionType().name())
                .actor(n.getActor() == null ? null :
                        NotificationItemResponse.Actor.builder()
                                .userId(n.getActor().getId())
                                .nickname(n.getActor().getNickname())
                                .profileImageUrl(n.getActor().getProfileImageUrl())
                                .build())
                .target(NotificationItemResponse.Target.builder()
                        .type(resolveTargetType(n))
                        .id(resolveTargetId(n))
                        .build())
                .build();
    }

    private String resolveTargetType(Notification n) {
        if (n.getTargetPhotoId() != null) return "PHOTO";
        if (n.getTargetAlbumId() != null) return "ALBUM";
        if (n.getTargetUserId() != null) return "USER";
        return "NONE";
    }

    private Long resolveTargetId(Notification n) {
        if (n.getTargetPhotoId() != null) return n.getTargetPhotoId();
        if (n.getTargetAlbumId() != null) return n.getTargetAlbumId();
        if (n.getTargetUserId() != null) return n.getTargetUserId();
        return null;
    }

    // 📌 단건 읽음 처리
    public void readOne(User user, Long id) {
        Notification n = notificationRepository.findById(id)
                .orElseThrow(() -> new BaseException(ErrorCode.NOTIFICATION_NOT_FOUND));

        if (!n.getReceiver().getId().equals(user.getId())) {
            throw new BaseException(ErrorCode.FORBIDDEN);
        }

        if (!n.isRead()) {
            n.setRead(true);
            notificationRepository.save(n);
        }
    }

    // 📌 전체 읽음 처리
    public long readAll(User user) {
        Page<Notification> page =
                notificationRepository.findByReceiverAndIsReadFalse(
                        user,
                        PageRequest.of(0, Integer.MAX_VALUE)
                );

        List<Notification> list = page.getContent();
        list.forEach(n -> n.setRead(true));
        notificationRepository.saveAll(list);

        return list.size();
    }
}
