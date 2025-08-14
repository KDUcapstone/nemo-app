package com.nemo.backend.domain.timeline.entity;

import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.global.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "timeline")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class Timeline extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String content;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "photo_id", nullable = false)
    private Photo photo;
}
