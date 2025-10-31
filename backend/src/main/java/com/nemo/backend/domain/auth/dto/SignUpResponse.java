// backend/src/main/java/com/nemo/backend/domain/auth/dto/SignUpResponse.java
package com.nemo.backend.domain.auth.dto;

/**
 * 회원 가입 성공 시 반환 DTO. 공개 가능한 사용자 정보만 포함한다.
 */
public class SignUpResponse {
    private Long id;
    private String email;
    private String nickname;
    private String profileImageUrl;

    public SignUpResponse(Long id, String email, String nickname, String profileImageUrl) {
        this.id = id;
        this.email = email;
        this.nickname = nickname;
        this.profileImageUrl = profileImageUrl;
    }

    public Long getId() { return id; }
    public String getEmail() { return email; }
    public String getNickname() { return nickname; }
    public String getProfileImageUrl() { return profileImageUrl; }
}
