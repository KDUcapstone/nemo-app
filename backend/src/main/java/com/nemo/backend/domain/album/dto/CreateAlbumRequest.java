// backend/src/main/java/com/nemo/backend/domain/album/dto/CreateAlbumRequest.java
package com.nemo.backend.domain.album.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public class CreateAlbumRequest {
    @NotBlank
    private String title;
    private String description;
    private Long coverPhotoId;

    @NotEmpty
    @JsonProperty("photoIds")
    @JsonAlias({"photoIdList"})
    private List<Long> photoIds;

    public CreateAlbumRequest() {}

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Long getCoverPhotoId() { return coverPhotoId; }
    public void setCoverPhotoId(Long coverPhotoId) { this.coverPhotoId = coverPhotoId; }

    public List<Long> getPhotoIds() { return photoIds; }
    public void setPhotoIds(List<Long> photoIds) { this.photoIds = photoIds; }
}
