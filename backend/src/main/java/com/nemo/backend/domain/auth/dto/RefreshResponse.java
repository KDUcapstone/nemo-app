// backend/src/main/java/com/nemo/backend/domain/auth/dto/RefreshResponse.java
package com.nemo.backend.domain.auth.dto;

/**
 * 액세스 토큰 재발급 응답 DTO.
 *
 * 응답 JSON 예:
 * {
 *   "accessToken": "xxx.yyy.zzz",
 *   "expiresIn": 3600
 * }
 */
public record RefreshResponse(String accessToken, long expiresIn) { }
