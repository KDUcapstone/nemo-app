// backend/src/main/java/com/nemo/backend/domain/album/dto/PhotoIdListRequest.java
package com.nemo.backend.domain.album.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

/**
 * 앨범 사진 추가/삭제 요청
 * 명세: photoIdList: number[]
 */
@Getter
@Setter
@NoArgsConstructor
public class PhotoIdListRequest {
    private List<Long> photoIdList;
}
