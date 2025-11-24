// com.nemo.backend.domain.user.service.UserService

package com.nemo.backend.domain.user.service;

import com.nemo.backend.domain.photo.service.PhotoStorage;
import com.nemo.backend.domain.user.dto.UpdateUserRequest;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final PhotoStorage photoStorage;

    private final String publicBaseUrl;  // ex) http://localhost:8080

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

    // =========================
    // JSON 기반 프로필 수정 (닉네임, URL 직접 설정)
    // =========================
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
            // 프론트가 이미 S3 URL을 알고 있는 경우 그대로 반영
            user.setProfileImageUrl(request.getProfileImageUrl());
        }

        return user;
    }

    // =========================
    // multipart/form-data 기반 프로필 수정
    //  - 닉네임(옵션)
    //  - 이미지 파일(옵션, 있으면 S3 업로드)
    // =========================
    @Transactional
    public User updateProfileMultipart(Long userId, String nickname, MultipartFile image) {

        if ((nickname == null || nickname.isBlank())
                && (image == null || image.isEmpty())) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "수정할 항목이 없습니다.");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_ALREADY_DELETED));

        if (nickname != null && !nickname.isBlank()) {
            user.setNickname(nickname);
        }

        if (image != null && !image.isEmpty()) {
            try {
                // S3 업로드 후 URL 저장
                String key = photoStorage.store(image);           // albums/..., profiles/... 등
                String profileUrl = publicBaseUrl + "/files/" + key;
                user.setProfileImageUrl(profileUrl);
            } catch (Exception e) {
                // S3PhotoStorage 가 던지는 예외를 공통 에러 코드로 래핑
                throw new ApiException(ErrorCode.STORAGE_FAILED,
                        "프로필 이미지 업로드 실패: " + e.getMessage(), e);
            }
        }

        return user;
    }

    /**
     * (필요하면 그대로 사용 가능한 단독 프로필 이미지 업로드)
     */
    @Transactional
    public String uploadProfileImage(Long userId, MultipartFile image) {
        if (image == null || image.isEmpty()) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "프로필 이미지 파일은 필수입니다.");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_ALREADY_DELETED));

        try {
            String key = photoStorage.store(image);
            String profileUrl = publicBaseUrl + "/files/" + key;
            user.setProfileImageUrl(profileUrl);
            return profileUrl;
        } catch (Exception e) {
            throw new ApiException(ErrorCode.STORAGE_FAILED, "프로필 이미지 업로드 실패: " + e.getMessage(), e);
        }
    }

    // =========================
    // 회원가입 전용 프로필 이미지 업로드
    //  - 아직 userId가 없으므로 User 엔티티는 수정하지 않음
    //  - S3에만 업로드하고 URL만 반환
    // =========================
    @Transactional
    public String uploadProfileImageForSignup(MultipartFile image) {

        if (image == null || image.isEmpty()) {
            throw new ApiException(ErrorCode.INVALID_ARGUMENT, "프로필 이미지 파일은 필수입니다.");
        }

        try {
            // S3PhotoStorage.store() 호출 → key 생성됨
            String key = photoStorage.store(image);

            // publicBaseUrl/files/{key} 형식의 접근 경로 생성
            return publicBaseUrl + "/files/" + key;

        } catch (Exception e) {
            throw new ApiException(
                    ErrorCode.STORAGE_FAILED,
                    "회원가입 프로필 이미지 업로드 실패: " + e.getMessage(),
                    e
            );
        }
    }

}
