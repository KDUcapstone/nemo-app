package com.nemo.backend.domain.user.service;

import com.nemo.backend.domain.photo.service.PhotoStorage;
import com.nemo.backend.domain.user.dto.UpdateUserRequest;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * Service layer for reading and updating user profile information.
 */
@Service
public class UserService {

    private final UserRepository userRepository;
    private final PhotoStorage photoStorage;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    private final String publicBaseUrl;  // ex) http://localhost:8080 or https://api.nemo.app

    public UserService(UserRepository userRepository,
                       PhotoStorage photoStorage,
                       @Value("${app.public-base-url:http://localhost:8080}") String publicBaseUrl) {
        this.userRepository = userRepository;
        this.photoStorage = photoStorage;
        this.publicBaseUrl = publicBaseUrl.replaceAll("/+$", "");
    }

    @Transactional(readOnly = true)
    public User getProfile(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_ALREADY_DELETED));
    }

    @Transactional
    public User updateProfile(Long userId, UpdateUserRequest request) {
        if (request == null || !request.hasAnyField()) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "수정할 항목이 없습니다.");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_ALREADY_DELETED));

        if (request.getNickname() != null && !request.getNickname().isEmpty()) {
            user.setNickname(request.getNickname());
        }

        if (request.getProfileImageUrl() != null && !request.getProfileImageUrl().isEmpty()) {
            // 프론트에서 S3 URL을 직접 줄 수도 있으니 허용
            user.setProfileImageUrl(request.getProfileImageUrl());
        }

        return user;
    }

    /**
     * 프로필 이미지 파일을 S3에 업로드하고,
     * 업로드된 파일의 public URL을 User.profileImageUrl 에 저장한 뒤 반환.
     */
    @Transactional
    public String uploadProfileImage(Long userId, MultipartFile image) {
        if (image == null || image.isEmpty()) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "프로필 이미지 파일은 필수입니다.");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_ALREADY_DELETED));

        try {
            // ✅ S3 업로드 (PhotoServiceImpl 이 쓰는 것과 같은 스토리지 사용)
            String key = photoStorage.store(image);  // ex) albums/2025-11-18/...jpg

            // ✅ 실제 접근 가능한 URL로 변환 (PhotoServiceImpl.toPublicUrl 과 동일 패턴)
            String profileUrl = publicBaseUrl + "/files/" + key;

            user.setProfileImageUrl(profileUrl);

            return profileUrl;
        } catch (Exception e) {
            // S3PhotoStorage 가 이미 ApiException(STORAGE_FAILED) 를 던지고 있으니
            // 여기선 그냥 래핑만
            throw new ApiException(ErrorCode.STORAGE_FAILED, "프로필 이미지 업로드 실패: " + e.getMessage(), e);
        }
    }
}
