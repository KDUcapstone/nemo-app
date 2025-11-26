package com.nemo.backend.domain.auth.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.nemo.backend.support.IntegrationTestSupport;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * AuthController 통합 테스트
 *
 * - /api/auth/refresh 엔드포인트를 실제 서버 환경에서 호출한다.
 * - 유효한 refreshToken으로는 새 accessToken을 재발급받고,
 *   잘못된 refreshToken으로는 에러 응답을 받는지 검증한다.
 */
class AuthControllerTest extends IntegrationTestSupport {

    // UserAuthController 쪽 엔드포인트 (회원가입/로그인)
    private static final String SIGNUP_URL  = "/api/users/signup";
    private static final String LOGIN_URL   = "/api/users/login";

    // AuthController 엔드포인트 (토큰 재발급)
    private static final String REFRESH_URL = "/api/auth/refresh";

    // ───────────────────────────────────────────────
    // 1) 토큰 재발급 성공 테스트
    // ───────────────────────────────────────────────

    @Test
    @DisplayName("POST /api/auth/refresh : 유효한 refreshToken으로 새 accessToken을 재발급받을 수 있다")
    void refresh_success() throws Exception {
        // given
        // 1. 테스트용 유저 회원가입
        String email = "refresh-success@example.com";
        String password = "SecurePass123!";

        signUp(email, password, "리프레시성공유저");

        // 2. 로그인해서 accessToken + refreshToken 발급
        Tokens tokens = loginAndGetTokens(email, password);

        // 3. 요청 바디 (RefreshRequest 역할, refreshToken 1개)
        Map<String, Object> body = new HashMap<>();
        body.put("refreshToken", tokens.refreshToken());

        // when & then
        // 4. /api/auth/refresh 호출
        String responseJson = mockMvc.perform(post(REFRESH_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                // RefreshResponse 구조: accessToken + expiresIn 이라고 가정
                .andExpect(jsonPath("$.accessToken").exists())
                .andExpect(jsonPath("$.expiresIn").isNumber())
                .andReturn()
                .getResponse()
                .getContentAsString();

        // 5. 실제 accessToken 값이 비어있지 않은지 추가 체크
        JsonNode node = objectMapper.readTree(responseJson);
        String newAccessToken = node.get("accessToken").asText();

        assertThat(newAccessToken).isNotBlank();
        // 구현에 따라 기존 accessToken과 다를 수도, 같을 수도 있으므로
        // "달라야 한다"까지는 강제하지 않음
    }

    // ───────────────────────────────────────────────
    // 2) 토큰 재발급 실패 테스트
    // ───────────────────────────────────────────────

    @Test
    @DisplayName("POST /api/auth/refresh : 잘못된 refreshToken이면 에러(INVALID_REFRESH)를 반환한다")
    void refresh_invalidToken() throws Exception {
        // given
        Map<String, Object> body = new HashMap<>();
        body.put("refreshToken", "this-is-not-a-valid-refresh-token");

        // when & then
        mockMvc.perform(post(REFRESH_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                // ApiException의 HttpStatus 에 따라 달라질 수 있음 (예: 401, 400 등)
                // 우선 4xx인지만 공통적으로 체크한다.
                .andExpect(status().is4xxClientError())
                .andExpect(jsonPath("$.error").value("INVALID_REFRESH"))
                .andExpect(jsonPath("$.message")
                        .value("리프레시 토큰이 유효하지 않거나 만료되었습니다."));
        // ↳ 위 error/message는 AuthController 내 Error record 생성 시 사용하는 값과 동일해야 한다.
    }

    // ───────────────────────────────────────────────
    // 🔧 아래는 테스트 공통 헬퍼 (회원가입/로그인 재사용)
    // ───────────────────────────────────────────────

    /**
     * 회원가입 API를 한 번 호출해 테스트 유저를 만든다.
     * - UserAuthController.signUp()을 통해 실제 로직을 태운다.
     */
    private void signUp(String email, String password, String nickname) throws Exception {
        Map<String, Object> body = new HashMap<>();
        body.put("email", email);
        body.put("password", password);
        body.put("nickname", nickname);

        mockMvc.perform(post(SIGNUP_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isCreated());
    }

    /**
     * 로그인 API를 호출해서 accessToken + refreshToken을 돌려준다.
     * - UserAuthController.login()을 그대로 사용한다.
     */
    private Tokens loginAndGetTokens(String email, String password) throws Exception {
        Map<String, Object> body = new HashMap<>();
        body.put("email", email);
        body.put("password", password);

        String responseJson = mockMvc.perform(post(LOGIN_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").exists())
                .andExpect(jsonPath("$.refreshToken").exists())
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode node = objectMapper.readTree(responseJson);
        String accessToken = node.get("accessToken").asText();
        String refreshToken = node.get("refreshToken").asText();

        assertThat(accessToken).isNotBlank();
        assertThat(refreshToken).isNotBlank();

        return new Tokens(accessToken, refreshToken);
    }

    /**
     * accessToken + refreshToken을 묶어주는 간단한 record
     */
    private record Tokens(String accessToken, String refreshToken) {}
}
