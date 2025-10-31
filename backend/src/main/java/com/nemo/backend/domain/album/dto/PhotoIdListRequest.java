// backend/src/main/java/com/nemo/backend/domain/album/dto/PhotoIdListRequest.java
package com.nemo.backend.domain.album.dto;

import java.util.List;
import jakarta.validation.constraints.NotEmpty;

/**
 * 사진 ID 목록을 요청 바디로 받을 때 사용.
 */
public class PhotoIdListRequest {
    @NotEmpty
    private List<Long> photoIdList;

    public List<Long> getPhotoIdList() { return photoIdList; }
}
