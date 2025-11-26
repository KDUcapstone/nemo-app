package com.nemo.backend.domain.auth.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 로그인 상태 비밀번호 변경 요청 DTO
 *
 * {
 *   "currentPassword": "OldPassword123!",
 *   "newPassword": "NewPassword!456",
 *   "confirmPassword": "NewPassword!456"
 * }
 */
@Getter
@Setter
@NoArgsConstructor
public class ChangePasswordRequest {

    private String currentPassword;
    private String newPassword;
    private String confirmPassword;
}
