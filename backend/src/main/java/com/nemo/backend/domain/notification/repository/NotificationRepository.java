package com.nemo.backend.domain.notification.repository;

import com.nemo.backend.domain.notification.entity.Notification;
import com.nemo.backend.domain.user.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    // ✔ 전체 알림 페이징 조회 (최신순 정렬은 Pageable에서 지정)
    Page<Notification> findByReceiver(User receiver, Pageable pageable);

    // ✔ 읽지 않은 알림만 페이징 조회
    Page<Notification> findByReceiverAndIsReadFalse(User receiver, Pageable pageable);

    // ✔ 안 읽은 알림 개수
    long countByReceiverAndIsReadFalse(User receiver);
}
