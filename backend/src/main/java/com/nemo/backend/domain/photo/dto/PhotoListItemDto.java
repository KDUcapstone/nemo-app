package com.nemo.backend.domain.photo.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 프론트 명세에 맞춘 사진 목록 아이템 DTO
 * fields: photoId, imageUrl, takenAt, location, brand, isFavorite
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PhotoListItemDto {
    private Long photoId;
    private String imageUrl;
    private String takenAt;   // ISO-8601 문자열 (예: 2025-07-20T17:23:00)
    private String location;  // 현재 엔티티에 위치명이 없으면 null/""로 반환
    private String brand;
    private boolean isFavorite; // 현재 즐겨찾기 기능 없으면 false 고정
}
