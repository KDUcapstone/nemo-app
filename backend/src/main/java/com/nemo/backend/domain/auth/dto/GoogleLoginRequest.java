package com.nemo.backend.domain.auth.dto;

import lombok.Getter;
import lombok.Setter;

/**
 * 구글 로그인 요청 DTO.
 * {
 *   "idToken": "google-id-token"
 * }
 */
@Getter
@Setter
public class GoogleLoginRequest {
    private String idToken;
}
