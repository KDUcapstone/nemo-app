// backend/src/main/java/com/nemo/backend/domain/auth/dto/SignUpResponse.java
package com.nemo.backend.domain.auth.dto;

/**
 * 회원 가입 성공 시 반환 DTO. 공개 가능한 사용자 정보만 포함한다.
 */
// SignUpResponse 생성자에서 nickname/profileImageUrl 기본값 처리
public class SignUpResponse {
    private Long userId;
    private String email;
    private String nickname;
    private String profileImageUrl;

    public SignUpResponse(Long userId, String email, String nickname, String profileImageUrl) {
        this.userId = userId;
        this.email = email;
        this.nickname = nickname != null ? nickname : "";
        this.profileImageUrl = profileImageUrl != null ? profileImageUrl : "";
    }
    // getters...
}
