package com.nemo.backend.domain.auth.dto;

import lombok.Getter;
import lombok.Setter;

/**
 * 카카오 로그인 요청 DTO.
 * {
 *   "accessToken": "kakao-user-access-token"
 * }
 */
@Getter
@Setter
public class KakaoLoginRequest {
    private String accessToken;
}
