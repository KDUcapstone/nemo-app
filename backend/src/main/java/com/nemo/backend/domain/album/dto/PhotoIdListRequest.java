package com.nemo.backend.domain.album.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

/**
 * 앨범 사진 추가/삭제 요청
 * 명세: photoIds: number[]
 */
@Getter
@Setter
@NoArgsConstructor
public class PhotoIdListRequest {

    // ✅ 명세에 맞춰 이름 변경
    private List<Long> photoIdList;
}
