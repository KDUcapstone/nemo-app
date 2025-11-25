// backend/src/main/java/com/nemo/backend/domain/auth/dto/RefreshResponse.java
package com.nemo.backend.domain.auth.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * 액세스 토큰 재발급 응답 DTO.
 *
 * 명세:
 * {
 *   "accessToken": "xxx",
 *   "refreshToken": "yyy" // 갱신된 경우만 포함
 * }
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record RefreshResponse(
        String accessToken,
        String refreshToken
) { }
