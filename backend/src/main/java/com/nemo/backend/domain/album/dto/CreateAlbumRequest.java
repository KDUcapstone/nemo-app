// backend/src/main/java/com/nemo/backend/domain/album/dto/CreateAlbumRequest.java
package com.nemo.backend.domain.album.dto;

import java.util.List;
import jakarta.validation.constraints.NotBlank;

/**
 * 앨범 생성 요청 DTO. title은 필수, description/coverPhotoId/photoIdList는 선택.
 */
public class CreateAlbumRequest {
    @NotBlank
    private String title;
    private String description;
    private Long coverPhotoId;
    private List<Long> photoIdList;

    public String getTitle() { return title; }
    public String getDescription() { return description; }
    public Long getCoverPhotoId() { return coverPhotoId; }
    public List<Long> getPhotoIdList() { return photoIdList; }
}
