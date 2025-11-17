package com.nemo.backend.domain.photo.service;

import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;

public interface PhotoService {

    PhotoResponseDto uploadHybrid(
            Long userId,
            String qrCode,
            MultipartFile image,
            String brand,
            String location,
            LocalDateTime takenAt,
            String tagListJson,
            String friendIdListJson,
            String memo
    );

    Page<PhotoResponseDto> list(Long userId, Pageable pageable);

    void delete(Long userId, Long photoId);
}
