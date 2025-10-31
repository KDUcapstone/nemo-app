// backend/src/main/java/com/nemo/backend/domain/album/dto/PhotoIdListRequest.java
package com.nemo.backend.domain.album.dto;

import java.util.List;
import jakarta.validation.constraints.NotEmpty;

public class PhotoIdListRequest {
    @NotEmpty
    private List<Long> photoIdList;

    public List<Long> getPhotoIdList() { return photoIdList; }
}
