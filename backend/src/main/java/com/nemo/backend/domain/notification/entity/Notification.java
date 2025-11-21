package com.nemo.backend.domain.notification.entity;

import com.nemo.backend.domain.user.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Getter
@Setter
@Builder
@AllArgsConstructor
@NoArgsConstructor
@Entity
@Table(name = "notification") // ✔ 테이블 이름 명시
@EntityListeners(AuditingEntityListener.class) // ✔ createdAt 자동 세팅용
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;  // 알림 PK

    // 알림을 받는 사람
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "receiver_id", nullable = false)
    private User receiver;

    // 알림을 발생시킨 사람 (없을 수도 있음)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "actor_id")
    private User actor;

    // 알림 종류
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private NotificationType type;

    // 프론트 이동용 action
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private NotificationActionType actionType;

    // 관련 리소스 ID들 (nullable)
    private Long targetPhotoId;
    private Long targetAlbumId;
    private Long targetUserId;

    // 사용자에게 그대로 보여줄 문구
    @Column(nullable = false, length = 200)
    private String message;

    // 읽음 여부
    @Column(nullable = false)
    private boolean isRead = false;

    // 생성 시각 (Auditing으로 자동 세팅)
    @CreatedDate
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;
}
