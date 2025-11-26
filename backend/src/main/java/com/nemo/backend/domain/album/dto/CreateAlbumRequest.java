package com.nemo.backend.domain.album.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

import java.util.List;

/**
 * 앨범 생성 요청 DTO
 * 명세:
 *  - title: string (필수)
 *  - description: string (선택)
 *  - coverPhotoId: number (선택)
 *  - photoIds: number[] (선택)
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateAlbumRequest {
    private String title;
    private String description;
    private Long coverPhotoId;
    private List<Long> photoIdList;
}
