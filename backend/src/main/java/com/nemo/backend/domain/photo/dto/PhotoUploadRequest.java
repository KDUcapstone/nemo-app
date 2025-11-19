package com.nemo.backend.domain.photo.dto;

import org.springframework.web.multipart.MultipartFile;

/**
 * 업로드 요청: (A) image 파일 업로드 or (B) qrUrl(다운로드/공유 페이지) 중 하나만 필요
 * 나머지 보조 필드는 선택
 */
public record PhotoUploadRequest(
        MultipartFile image,   // A 경로: 순수 이미지 파일
        String qrUrl,          // B 경로: 다운로드/공유 페이지 URL (QR payload)
        String qrCode,         // 과거 프론트 호환용 (qrUrl로 유도)
        String takenAt,        // ISO 문자열(선택)
        String location,       // 선택
        String brand,          // 선택
        String memo            // 선택
) {}
