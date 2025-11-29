package com.nemo.backend.domain.user.entity;

import com.nemo.backend.global.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "users")
public class User extends BaseEntity {

    @Getter
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Getter
    @Setter
    @Column(nullable = false, unique = true, length = 191)
    private String email;

    @Getter
    @Setter
    @Column(nullable = false)
    private String password;

    // 닉네임은 DB에서 null 허용이라도, 응답 DTO에서 빈 문자열로 보정됨
    @Getter
    @Setter
    @Column(name = "nickname")
    private String nickname;

    @Getter
    @Setter
    @Column(name = "profile_image_url")
    private String profileImageUrl;

    @Getter
    @Setter
    private String provider;

    @Getter
    @Setter
    private String socialId;

    @Getter
    @Setter
    @Column(nullable = false, length = 20)
    private String planType = "FREE";   // FREE, PLUS 등

    @Getter
    @Setter
    @Column(nullable = false)
    private int maxPhotoCount = 20;     // 최대 저장 사진 장수

}
