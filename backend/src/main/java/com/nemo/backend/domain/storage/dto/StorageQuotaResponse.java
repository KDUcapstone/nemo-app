package com.nemo.backend.domain.storage.dto;

import lombok.Builder;
import lombok.Getter;

/**
 * 저장 한도/사용량 조회 응답 DTO
 */
@Getter
@Builder
public class StorageQuotaResponse {

    private String planType;     // FREE, PLUS ...
    private int maxPhotos;       // 최대 저장 사진 장수
    private int usedPhotos;      // 사용한 사진 장수
    private int remainPhotos;    // 남은 장수
    private double usagePercent; // 사용률 (%)
}
