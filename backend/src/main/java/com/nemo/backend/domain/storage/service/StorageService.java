package com.nemo.backend.domain.storage.service;

import com.nemo.backend.domain.photo.repository.PhotoRepository;
import com.nemo.backend.domain.storage.dto.StorageQuotaResponse;
import com.nemo.backend.domain.storage.exception.PhotoLimitExceededException;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class StorageService {

    private final UserRepository userRepository;
    private final PhotoRepository photoRepository;

    // ✅ 저장 한도/사용량 조회
    public StorageQuotaResponse getQuota(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));

        int maxPhotos = user.getMaxPhotoCount();
        int usedPhotos = photoRepository.countByUserIdAndDeletedIsFalse(userId);
        int remainPhotos = Math.max(0, maxPhotos - usedPhotos);

        double usagePercent = 0.0;
        if (maxPhotos > 0) {
            usagePercent = (usedPhotos / (double) maxPhotos) * 100.0;
            usagePercent = Math.round(usagePercent * 10) / 10.0;
        }

        return StorageQuotaResponse.builder()
                .planType(user.getPlanType())
                .maxPhotos(maxPhotos)
                .usedPhotos(usedPhotos)
                .remainPhotos(remainPhotos)
                .usagePercent(usagePercent)
                .build();
    }

    // ✅ 업로드 전에 한도 체크 (초과 시 예외 던짐)
    public void checkPhotoLimitOrThrow(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));

        int maxPhotos = user.getMaxPhotoCount();
        int usedPhotos = photoRepository.countByUserIdAndDeletedIsFalse(userId);

        if (usedPhotos >= maxPhotos) {
            throw new PhotoLimitExceededException(maxPhotos, usedPhotos);
        }
    }
}
