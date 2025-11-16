package com.nemo.backend.domain.album.entity;

import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.global.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(
        name = "album_share",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_album_share_album_user",
                columnNames = {"album_id", "user_id"}
        )
)
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class AlbumShare extends BaseEntity {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "album_id", nullable = false)
    private Album album;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;   // VIEW / EDIT / MANAGE

    @Column(nullable = false)
    private Boolean active = true;

    public enum Role {
        VIEW, EDIT, MANAGE
    }
}
