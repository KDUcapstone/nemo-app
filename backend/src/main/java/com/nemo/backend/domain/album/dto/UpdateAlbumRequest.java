// backend/src/main/java/com/nemo/backend/domain/album/dto/UpdateAlbumRequest.java
package com.nemo.backend.domain.album.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 앨범 수정 요청
 * 명세: title, description, coverPhotoId (모두 선택)
 */
@Getter
@Setter
@NoArgsConstructor
public class UpdateAlbumRequest {

    private String title;        // ❌ 선택
    private String description;  // ❌ 선택
    private Long coverPhotoId;   // ❌ 선택
}
