package com.nemo.backend.domain.auth.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.nemo.backend.support.IntegrationTestSupport;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * DevTokenController 통합 테스트
 *
 * - 개발용 유저 생성(seed) 및 토큰 발급 기능을 검증한다.
 * - @Profile({"local","dev"}) 에 의해 dev 환경에서만 작동하기 때문에
 *   테스트도 @ActiveProfiles("dev")로 지정해야 한다.
 */
@ActiveProfiles("dev")   // ⭐ dev 프로필에서만 DevTokenController 활성화됨
class DevTokenControllerTest extends IntegrationTestSupport {

    private static final String SEED_URL = "/api/auth/dev/seed";

    // ───────────────────────────────────────────────
    // 1) 새 이메일로 seed 호출 → 유저 생성 + 토큰 발급 성공
    // ───────────────────────────────────────────────

    @Test
    @DisplayName("POST /api/auth/dev/seed : 새로운 이메일이면 dev 계정을 생성하고 토큰을 발급한다")
    void seed_createNewUser() throws Exception {

        // given
        String email = "devtest1@nemo.app";

        // when
        String responseJson = mockMvc.perform(post(SEED_URL)
                        .param("email", email)) // 쿼리 파라미터 방식
                .andExpect(status().isOk())
                // 응답 기본 필드 존재 확인
                .andExpect(jsonPath("$.userId").exists())
                .andExpect(jsonPath("$.email").value(email))
                .andExpect(jsonPath("$.accessToken").exists())
                .andExpect(jsonPath("$.refreshToken").exists())
                .andExpect(jsonPath("$.refreshExpiry").exists())
                .andReturn()
                .getResponse()
                .getContentAsString();

        // then
        JsonNode node = objectMapper.readTree(responseJson);

        assertThat(node.get("email").asText()).isEqualTo(email);
        assertThat(node.get("accessToken").asText()).isNotBlank();
        assertThat(node.get("refreshToken").asText()).contains("dev-refresh-token");
    }

    // ───────────────────────────────────────────────
    // 2) 기존 유저 email로 호출 → 기존 유저에 대한 토큰만 갱신
    // ───────────────────────────────────────────────

    @Test
    @DisplayName("POST /api/auth/dev/seed : 기존 유저 이메일이면 새로 만들지 않고 토큰만 발급한다")
    void seed_existingUser() throws Exception {

        // given
        String email = "devexist@nemo.app";

        // 1) 먼저 한 번 호출해서 유저 생성
        String firstJson = mockMvc.perform(post(SEED_URL).param("email", email))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        Long existingUserId = objectMapper.readTree(firstJson).get("userId").asLong();

        // 2) 두 번째 호출 (유저 재생성 X → 같은 userId가 반환되어야 정상)
        String secondJson = mockMvc.perform(post(SEED_URL).param("email", email))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").exists())
                .andReturn()
                .getResponse()
                .getContentAsString();

        Long returnedUserId = objectMapper.readTree(secondJson).get("userId").asLong();

        // then
        assertThat(returnedUserId).isEqualTo(existingUserId);
    }

    // ───────────────────────────────────────────────
    // 3) userId 기준 seed → 해당 userId의 계정을 그대로 사용
    // ───────────────────────────────────────────────

    @Test
    @DisplayName("POST /api/auth/dev/seed : userId 파라미터로 호출하면 해당 유저를 기준으로 토큰이 발급된다")
    void seed_byUserId() throws Exception {

        // given
        String email = "devuserid@nemo.app";

        // 유저 생성
        String json1 = mockMvc.perform(post(SEED_URL).param("email", email))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        Long createdUserId = objectMapper.readTree(json1).get("userId").asLong();

        // when
        // 같은 userId로 다시 호출
        String json2 = mockMvc.perform(post(SEED_URL).param("userId", createdUserId.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(createdUserId))
                .andExpect(jsonPath("$.accessToken").exists())
                .andReturn()
                .getResponse()
                .getContentAsString();

        // then
        JsonNode node = objectMapper.readTree(json2);
        assertThat(node.get("accessToken").asText()).isNotBlank();
    }
}
