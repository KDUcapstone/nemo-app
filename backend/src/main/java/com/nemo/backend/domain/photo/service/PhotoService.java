// backend/src/main/java/com/nemo/backend/domain/photo/service/PhotoService.java
package com.nemo.backend.domain.photo.service;

import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.dto.SelectedPhotosDownloadUrlsResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.List;

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

    // ✅ 브랜드/태그까지 포함한 메인 시그니처
    Page<PhotoResponseDto> list(
            Long userId,
            Pageable pageable,
            Boolean favorite,
            String brand,
            String tag
    );

    // ✅ 기존 시그니처 유지용 오버로드 (favorite만)
    default Page<PhotoResponseDto> list(Long userId, Pageable pageable, Boolean favorite) {
        return list(userId, pageable, favorite, null, null);
    }

    // ✅ 기존 기본 오버로드
    default Page<PhotoResponseDto> list(Long userId, Pageable pageable) {
        return list(userId, pageable, null, null, null);
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

    // ✅ 선택된 사진들에 대한 다운로드 URL 목록 조회
    SelectedPhotosDownloadUrlsResponse getDownloadUrls(Long userId, List<Long> photoIdList);
}
