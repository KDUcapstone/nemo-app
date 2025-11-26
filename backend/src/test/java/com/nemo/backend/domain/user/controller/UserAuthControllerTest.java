package com.nemo.backend.domain.user.controller;

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

class UserAuthControllerTest extends IntegrationTestSupport {

    private static final String SIGNUP_URL = "/api/users/signup";
    private static final String LOGIN_URL  = "/api/users/login";
    private static final String LOGOUT_URL = "/api/users/logout";

    // ───────────────── 회원가입 ─────────────────

    @Test
    @DisplayName("회원가입 성공: 201, 유저 정보가 반환된다")
    void signUp_success() throws Exception {
        Map<String, Object> body = new HashMap<>();
        body.put("email", "auth-signup@example.com");
        body.put("password", "SecurePass123!");
        body.put("nickname", "네컷러버");

        mockMvc.perform(post(SIGNUP_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.userId").exists())
                .andExpect(jsonPath("$.email").value("auth-signup@example.com"))
                .andExpect(jsonPath("$.nickname").value("네컷러버"))
                .andExpect(jsonPath("$.createdAt").exists());
        // profileImageUrl 은 null일 수도 있어서 필요하면 추가 검사
    }

    @Test
    @DisplayName("회원가입 실패: 같은 이메일로 두 번 요청하면 409 EMAIL_ALREADY_EXISTS")
    void signUp_duplicateEmail() throws Exception {
        String email = "dup-auth@example.com";

        // 1번: 정상 회원가입
        signUp(email, "SecurePass123!", "중복테스트");

        // 2번: 같은 이메일로 다시 시도
        Map<String, Object> body = new HashMap<>();
        body.put("email", email);
        body.put("password", "SecurePass123!");
        body.put("nickname", "다른닉네임");

        mockMvc.perform(post(SIGNUP_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error").value("EMAIL_ALREADY_EXISTS"));
        // 실제 구현에서 에러코드/상태코드가 다르면 여기만 맞춰주면 됨
    }

    // ───────────────── 로그인 ─────────────────

    @Test
    @DisplayName("로그인 성공: accessToken, refreshToken, user 정보가 반환된다")
    void login_success() throws Exception {
        String email = "auth-login@example.com";
        String password = "SecurePass123!";
        String nickname = "로그인유저";

        signUp(email, password, nickname);

        Map<String, Object> body = new HashMap<>();
        body.put("email", email);
        body.put("password", password);

        String responseJson = mockMvc.perform(post(LOGIN_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").exists())
                .andExpect(jsonPath("$.refreshToken").exists())
                .andExpect(jsonPath("$.expiresIn").isNumber())
                .andExpect(jsonPath("$.user.userId").exists())
                .andExpect(jsonPath("$.user.nickname").value(nickname))
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode node = objectMapper.readTree(responseJson);
        assertThat(node.get("accessToken").asText()).isNotBlank();
        assertThat(node.get("refreshToken").asText()).isNotBlank();
    }

    @Test
    @DisplayName("로그인 실패: 비밀번호가 틀리면 401 INVALID_CREDENTIALS")
    void login_invalidCredentials() throws Exception {
        String email = "auth-wrong@example.com";
        String password = "SecurePass123!";

        signUp(email, password, "비번테스트");

        Map<String, Object> body = new HashMap<>();
        body.put("email", email);
        body.put("password", "WrongPass!!");

        mockMvc.perform(post(LOGIN_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("INVALID_CREDENTIALS"));
    }

    // ───────────────── 로그아웃 ─────────────────

    @Test
    @DisplayName("로그아웃 성공: Authorization 헤더에 토큰을 보내면 200과 'logged out' 메시지를 반환한다")
    void logout_success() throws Exception {
        String email = "auth-logout@example.com";
        String password = "SecurePass123!";

        signUp(email, password, "로그아웃유저");

        // 먼저 로그인해서 accessToken 얻기
        Tokens tokens = loginAndGetTokens(email, password);

        mockMvc.perform(post(LOGOUT_URL)
                        .header("Authorization", bearer(tokens.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("logged out"));
        // ⚠️ 현재 컨트롤러는 body에 refreshToken 안 받음 (스펙이랑 다르면 나중에 맞춰야 함)
    }

    // ──────────────── 헬퍼 메서드/record ────────────────

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
        return new Tokens(
                node.get("accessToken").asText(),
                node.get("refreshToken").asText()
        );
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    private record Tokens(String accessToken, String refreshToken) {}
}
