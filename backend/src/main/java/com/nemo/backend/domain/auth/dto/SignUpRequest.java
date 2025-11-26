// backend/src/main/java/com/nemo/backend/domain/auth/dto/SignUpRequest.java
package com.nemo.backend.domain.auth.dto;

import lombok.Getter;
import lombok.Setter;

/**
 * 회원가입 요청 DTO.
 * - email
 * - password
 * - nickname
 * - profileImageUrl: 프로필 이미지 URL (선택)
 *
 * 실제 프로필 이미지는 Storage API(S3 업로드)로 먼저 업로드한 뒤,
 * 그 URL을 profileImageUrl로 전달한다.
 */
@Getter
@Setter
public class SignUpRequest {

    private String email;
    private String password;
    private String nickname;
    private String profileImageUrl;
}
