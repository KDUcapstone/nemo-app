package com.nemo.backend.domain.storage.exception;

import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import lombok.Getter;

/**
 * 저장 한도를 초과했을 때 사용하는 예외.
 */
@Getter
public class PhotoLimitExceededException extends ApiException {

    private final int maxPhotos;
    private final int usedPhotos;

    public PhotoLimitExceededException(int maxPhotos, int usedPhotos) {
        super(
                ErrorCode.PHOTO_LIMIT_EXCEEDED,
                "저장 가능한 최대 사진 장수(" + maxPhotos + "장)를 초과했습니다."
        );
        this.maxPhotos = maxPhotos;
        this.usedPhotos = usedPhotos;
    }
}
