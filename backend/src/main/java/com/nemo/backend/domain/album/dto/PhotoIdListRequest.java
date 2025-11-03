// backend/src/main/java/com/nemo/backend/domain/album/dto/PhotoIdListRequest.java
package com.nemo.backend.domain.album.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public class PhotoIdListRequest {
    @NotEmpty
    @JsonProperty("photoIds")
    @JsonAlias({"photoIdList"})
    private List<Long> photoIds;

    public PhotoIdListRequest() {}

    public List<Long> getPhotoIds() { return photoIds; }
    public void setPhotoIds(List<Long> photoIds) { this.photoIds = photoIds; }
}
