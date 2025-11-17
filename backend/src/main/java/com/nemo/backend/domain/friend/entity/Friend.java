package com.nemo.backend.domain.friend.entity;

import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.global.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

/**
 * 친구(Friend) 엔티티
 * -----------------------
 * - 두 사용자 간의 친구 관계를 나타냄
 * - 예: A가 B에게 친구 요청을 보내면 Friend(user=A, friend=B)
 * - 친구 요청이 수락되면 상태(status)가 ACCEPTED로 변경됨
 */
@Entity
@Table(
        name = "friend",
        uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "friend_id"}) // 중복 친구 방지
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Friend extends BaseEntity {

    /**
     * 친구 관계의 고유 ID (자동 증가)
     */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * 친구 요청을 보낸 사용자 (나)
     * - 예: 내가 친구 요청을 보냈다면 user = 나 자신
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /**
     * 친구 요청의 대상 사용자 (상대방)
     * - 예: 내가 친구 요청을 보냈다면 friend = 상대방
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "friend_id", nullable = false)
    private User friend;

    /**
     * 친구 상태 (요청 중인지, 수락되었는지)
     * - PENDING: 친구 요청을 보낸 상태
     * - ACCEPTED: 친구 요청이 수락된 상태
     */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private FriendStatus status;

    /**
     * 친구 요청 생성 메서드 (정적 팩토리 메서드)
     * ---------------------
     * - user가 friend에게 친구 요청을 보낼 때 사용
     * - 상태는 기본적으로 PENDING(대기중)으로 저장
     */
    public static Friend createRequest(User user, User friend) {
        return Friend.builder()
                .user(user)
                .friend(friend)
                .status(FriendStatus.PENDING)
                .build();
    }

    /**
     * 친구 요청 수락 처리
     * ---------------------
     * - 친구 요청이 수락되면 상태를 ACCEPTED로 변경
     */
    public void accept() {
        this.status = FriendStatus.ACCEPTED;
    }
}
