package com.nemo.backend.domain.album.entity;

import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.global.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

/**
 * 앨범 공유 정보
 * - 누가 어떤 권한으로 이 앨범을 공유받았는지 저장
 */
@Entity
@Table(
        name = "album_share",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_album_share_album_user",
                columnNames = {"album_id", "user_id"}
        )
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AlbumShare extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 공유 대상 앨범 */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "album_id", nullable = false)
    private Album album;

    /** 공유 받은 사용자 */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** 권한 (VIEWER / EDITOR / CO_OWNER) */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

    /** 공유 요청 상태 (대기/수락/거절) */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Status status;

    /** 활성 여부 (공유 해제/거절 시 false) */
    @Column(nullable = false)
    private Boolean active = true;

    /** 공유 권한 */
    public enum Role {
        VIEWER,   // 보기만 가능
        EDITOR,   // 사진 추가/삭제 등 수정 가능
        CO_OWNER  // 수정 + 공유/권한 관리까지 가능 (공동 소유자)
    }

    /** 공유 요청 상태 */
    public enum Status {
        PENDING,   // 초대 보냈고 아직 수락/거절 안 함
        ACCEPTED,  // 수락된 상태
        REJECTED   // 거절/취소된 상태
    }
}
