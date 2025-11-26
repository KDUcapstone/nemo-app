package com.nemo.backend.domain.user.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.nemo.backend.support.IntegrationTestSupport;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * UserController 통합 테스트
 *
 * - 실제 서버를 띄운 상태에서
 *   /api/users/me (GET, DELETE)를 직접 호출해서 검증한다.
 * - 인증(JWT)이 필요하기 때문에
 *   UserAuthController의 회원가입/로그인 API를 같이 사용한다.
 */
class UserControllerTest extends IntegrationTestSupport {

    // UserAuthController 쪽 엔드포인트
    private static final String SIGNUP_URL = "/api/users/signup";
    private static final String LOGIN_URL  = "/api/users/login";

    // UserController 엔드포인트
    private static final String ME_URL     = "/api/users/me";

    // ───────────────────────────────────────────────
    // 1) 내 정보 조회 테스트
    // ───────────────────────────────────────────────

    @Test
    @DisplayName("GET /api/users/me : 로그인된 사용자의 프로필 정보를 조회할 수 있다")
    void getMe_success() throws Exception {
        // given
        // 1. 테스트용 유저 회원가입
        String email = "me-test@example.com";
        String password = "SecurePass123!";
        String nickname = "프로필테스트유저";

        signUp(email, password, nickname);

        // 2. 로그인해서 accessToken 발급
        Tokens tokens = loginAndGetTokens(email, password);

        // when & then
        // 3. Authorization 헤더에 accessToken을 넣고 /api/users/me 호출
        mockMvc.perform(get(ME_URL)
                        .header("Authorization", bearer(tokens.accessToken())))
                .andExpect(status().isOk())
                // 응답 JSON 필드 검증 (UserProfileResponse 구조)
                .andExpect(jsonPath("$.userId").exists())
                .andExpect(jsonPath("$.email").value(email))
                .andExpect(jsonPath("$.nickname").value(nickname))
                .andExpect(jsonPath("$.profileImageUrl").exists())
                .andExpect(jsonPath("$.createdAt").exists());
    }

    // ───────────────────────────────────────────────
    // 2) 회원탈퇴 테스트
    // ───────────────────────────────────────────────

    @Test
    @DisplayName("DELETE /api/users/me : 비밀번호를 보내면 회원탈퇴가 되고, 다시 로그인할 수 없다")
    void deleteMe_success() throws Exception {
        // given
        // 1. 테스트용 유저 회원가입
        String email = "delete-test@example.com";
        String password = "MySecurePass123!";
        String nickname = "탈퇴테스트유저";

        signUp(email, password, nickname);

        // 2. 로그인해서 accessToken 발급
        Tokens tokens = loginAndGetTokens(email, password);

        // 3. 탈퇴 요청 바디 (DeleteAccountRequest 역할)
        Map<String, Object> deleteBody = new HashMap<>();
        deleteBody.put("password", password);

        // when & then
        // 4. Authorization + 비밀번호를 보내서 /api/users/me DELETE 호출
        mockMvc.perform(delete(ME_URL)
                        .header("Authorization", bearer(tokens.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(deleteBody)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("회원탈퇴 완료"));

        // 5. 탈퇴 이후, 같은 이메일/비밀번호로 다시 로그인 시도 → 실패해야 정상
        Map<String, Object> loginBody = new HashMap<>();
        loginBody.put("email", email);
        loginBody.put("password", password);

        mockMvc.perform(post(LOGIN_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginBody)))
                .andExpect(status().isUnauthorized());
        // ↳ 실제 구현에서 상태코드가 401이 아닐 경우, 여기만 맞춰서 수정
    }

    // ───────────────────────────────────────────────
    // 🔧 아래는 테스트에서 돌려쓰는 헬퍼 메서드 모음
    //    (UserAuthController를 통해 회원가입/로그인하는 공통 로직)
    // ───────────────────────────────────────────────

    /**
     * 회원가입 API를 한 번 호출해 테스트 유저를 만든다.
     * - UserAuthController.signUp()을 그대로 사용
     * - 성공 여부만 확인하고, 응답 내용은 따로 쓰지 않는다.
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
     * - UserAuthController.login()을 그대로 사용
     * - /api/users/me, /api/users/me(DELETE) 호출용으로 accessToken을 사용
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
     * Authorization 헤더에 넣을 "Bearer {token}" 문자열을 만들어준다.
     */
    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    /**
     * accessToken + refreshToken을 같이 다닐 때 쓰는 간단한 record
     */
    private record Tokens(String accessToken, String refreshToken) {}
}
