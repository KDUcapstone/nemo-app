package com.nemo.backend.domain.album.entity;

import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.global.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "album")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class Album extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    private String description;

    // ✅ 앨범 썸네일 URL (명세의 coverPhotoUrl)
    @Column(name = "cover_photo_url")
    private String coverPhotoUrl;

    // 소유자 (User)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    // ✅ 앨범에 포함된 사진 (N:N)
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
            name = "album_photos",
            joinColumns = @JoinColumn(name = "album_id"),
            inverseJoinColumns = @JoinColumn(name = "photo_id")
    )
    private List<Photo> photos = new ArrayList<>();
}
