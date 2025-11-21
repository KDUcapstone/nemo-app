// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumShareRequest.java
package com.nemo.backend.domain.album.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

/**
 * 앨범 공유 요청
 * 명세: friendIdList
 */
@Getter
@Setter
@NoArgsConstructor
public class AlbumShareRequest {
    private List<Long> friendIdList;
}
