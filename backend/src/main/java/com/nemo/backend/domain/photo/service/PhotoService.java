package com.nemo.backend.domain.photo.service;

import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.web.multipart.MultipartFile;

public interface PhotoService {
    PhotoResponseDto upload(Long userId, MultipartFile qrFile);
    Page<PhotoResponseDto> list(Long userId, Pageable pageable);
    void delete(Long userId, Long photoId);
}
