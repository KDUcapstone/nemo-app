package com.nemo.backend.domain.user.dto;

import java.time.LocalDateTime;

/**
 * 현재 로그인한 사용자의 프로필 정보를 나타내는 DTO.
 * null 값이 전달될 경우 빈 문자열로 대체하여 Flutter에서
 *  `Null is not a subtype of String` 오류를 방지합니다.
 */
public class UserProfileResponse {
    private Long id;             // 사용자 ID
    private String email;        // 이메일
    private String nickname;     // 닉네임 (null → "")
    private String profileImage; // 프로필 이미지 URL (null → "")
    private String createdAt;    // 가입일 (ISO‑8601 문자열)

    // 기본 생성자
    public UserProfileResponse() {}

    public UserProfileResponse(Long id,
                               String email,
                               String nickname,
                               String profileImage,
                               LocalDateTime createdAt) {
        this.id = (id == null ? 0L : id);
        this.email = (email == null ? "" : email);
        this.nickname = (nickname == null ? "" : nickname);
        this.profileImage = (profileImage == null ? "" : profileImage);
        this.createdAt = (createdAt == null ? "" : createdAt.toString());
    }

    // 게터들
    public Long getId() { return id; }
    public String getEmail() { return email; }
    public String getNickname() { return nickname; }
    public String getProfileImage() { return profileImage; }
    public String getCreatedAt() { return createdAt; }
}
