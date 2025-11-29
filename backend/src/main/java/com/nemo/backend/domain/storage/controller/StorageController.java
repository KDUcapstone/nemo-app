package com.nemo.backend.domain.storage.controller;

import com.nemo.backend.domain.auth.util.AuthExtractor;
import com.nemo.backend.domain.storage.dto.StorageQuotaResponse;
import com.nemo.backend.domain.storage.service.StorageService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Storage", description = "저장 한도/사용량 조회 API")
@RestController
@RequestMapping(
        value = "/api/storage",
        produces = "application/json; charset=UTF-8"
)
@RequiredArgsConstructor
public class StorageController {

    private final StorageService storageService;
    private final AuthExtractor authExtractor;

    /**
     * 저장 한도/사용량 조회
     * GET /api/storage/quota
     */
    @GetMapping("/quota")
    public ResponseEntity<StorageQuotaResponse> getQuota(HttpServletRequest request) {
        // 1️⃣ Authorization 헤더에서 userId 추출
        String authorization = request.getHeader("Authorization");
        Long userId = authExtractor.extractUserId(authorization);

        // 2️⃣ 서비스에서 계산
        StorageQuotaResponse quota = storageService.getQuota(userId);

        // 3️⃣ 그대로 응답
        return ResponseEntity
                .ok()
                .contentType(MediaType.APPLICATION_JSON)
                .body(quota);
    }
}
