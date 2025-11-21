// backend/src/main/java/com/nemo/backend/domain/album/dto/CreateAlbumRequest.java
package com.nemo.backend.domain.album.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

/**
 * 앨범 생성 요청
 * 명세: title, description, coverPhotoId, photoIdList
 */
@Getter
@Setter
@NoArgsConstructor
public class CreateAlbumRequest {

    private String title;              // ✅ 필수 (서버에서 검증)
    private String description;        // ❌ 선택
    private Long coverPhotoId;         // ❌ 선택
    private List<Long> photoIdList;    // ❌ 선택
}
