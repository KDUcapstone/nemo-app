package com.nemo.backend.domain.album.entity;

import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.global.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(
        name = "album_favorite",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_album_favorite_album_user",
                columnNames = {"album_id", "user_id"}
        )
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AlbumFavorite extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 즐겨찾기한 앨범 */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "album_id", nullable = false)
    private Album album;

    /** 즐겨찾기한 사용자 */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
}
