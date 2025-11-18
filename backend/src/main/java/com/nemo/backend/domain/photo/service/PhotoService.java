// backend/src/main/java/com/nemo/backend/domain/photo/service/PhotoService.java

package com.nemo.backend.domain.photo.service;

import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;

public interface PhotoService {

    PhotoResponseDto uploadHybrid(
            Long userId,
            String qrCodeOrUrl,
            MultipartFile image,
            String brand,
            String location,
            LocalDateTime takenAt,
            String tagListJson,
            String friendIdListJson,
            String memo
    );

    // ✅ favorite 필터 적용 가능하도록 확장
    Page<PhotoResponseDto> list(Long userId, Pageable pageable, Boolean favorite);

    // ✅ 기존 컨트롤러 호환용 오버로드
    default Page<PhotoResponseDto> list(Long userId, Pageable pageable) {
        return list(userId, pageable, null);
    }

    void delete(Long userId, Long photoId);

    PhotoResponseDto getDetail(Long userId, Long photoId);

    PhotoResponseDto updateDetails(
            Long userId,
            Long photoId,
            LocalDateTime takenAt,
            String location,
            String brand,
            String memo
    );

    boolean toggleFavorite(Long userId, Long photoId);
}
