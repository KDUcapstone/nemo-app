// backend/src/main/java/com/nemo/backend/domain/album/service/AlbumService.java
package com.nemo.backend.domain.album.service;

import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.beans.factory.annotation.Value;   // ✅ 이것만 남기기

import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.repository.AlbumRepository;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.domain.photo.repository.PhotoRepository;
import com.nemo.backend.domain.photo.service.PhotoStorage;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

@Service
@Transactional(readOnly = true)
public class AlbumService {

    private final AlbumRepository albumRepository;
    private final PhotoRepository photoRepository;
    private final PhotoStorage photoStorage;   // ✅ 추가

    private final String publicBaseUrl;

    @PersistenceContext
    private EntityManager em;

    /** 생성자 주입 (PhotoStorage + publicBaseUrl) */
    public AlbumService(
            AlbumRepository albumRepository,
            PhotoRepository photoRepository,
            PhotoStorage photoStorage,
            @Value("${app.public-base-url:http://localhost:8080}") String publicBaseUrl
    ) {
        this.albumRepository = albumRepository;
        this.photoRepository = photoRepository;  // ✅ 여기 한 번만
        this.photoStorage = photoStorage;
        this.publicBaseUrl = publicBaseUrl.replaceAll("/+$", "");
    }

    /** 로그인 사용자 앨범 목록 조회 */
    public List<AlbumSummaryResponse> getAlbums(Long userId) {
        return albumRepository.findAll().stream()
                .filter(a -> a.getUser() != null && userId.equals(a.getUser().getId()))
                .map(this::toSummary)
                .collect(Collectors.toList());
    }

    /** 특정 앨범 상세 조회 */
    public AlbumDetailResponse getAlbum(Long userId, Long albumId) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));
        if (a.getUser() == null || !userId.equals(a.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다.");
        }
        return toDetail(a);
    }

    /** 앨범 생성 */
    @Transactional
    public AlbumDetailResponse createAlbum(Long userId, CreateAlbumRequest req) {
        if (req.getTitle() == null || req.getTitle().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "앨범 이름(title)은 필수입니다.");
        }

        Album a = new Album();
        a.setName(req.getTitle());
        a.setDescription(req.getDescription());

        // User#setId 불가 → 프록시로 주입
        User ownerRef = em.getReference(User.class, userId);
        a.setUser(ownerRef);

        Album saved = albumRepository.save(a);

        // 사진 연결
        if (req.getPhotoIds() != null && !req.getPhotoIds().isEmpty()) {
            List<Photo> photos = photoRepository.findAllById(req.getPhotoIds());
            for (Photo p : photos) {
                p.setAlbum(saved);
            }
            photoRepository.saveAll(photos);

            // 🔥 추가: 앨범 입장에서도 사진 리스트를 채워줌
            saved.setPhotos(photos);
        }

        // ✅ 자동 썸네일: 앨범에 사진이 있고 아직 coverPhotoUrl 이 없으면
        autoSetThumbnailIfMissing(saved);

        return toDetail(saved);
    }

    /** 앨범에 사진 추가 */
    @Transactional
    public void addPhotos(Long userId, Long albumId, List<Long> photoIds) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));
        if (a.getUser() == null || !userId.equals(a.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다.");
        }

        List<Photo> photos = photoRepository.findAllById(photoIds);
        for (Photo p : photos) {
            p.setAlbum(a);
        }
        photoRepository.saveAll(photos);

        // 새로 사진이 추가되고 썸네일이 비어 있으면 자동 지정
        autoSetThumbnailIfMissing(a);
    }

    /** 앨범에서 사진 제거 */
    @Transactional
    public void removePhotos(Long userId, Long albumId, List<Long> photoIds) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));
        if (a.getUser() == null || !userId.equals(a.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다.");
        }

        List<Photo> photos = photoRepository.findAllById(photoIds);
        for (Photo p : photos) {
            if (p.getAlbum() != null && albumId.equals(p.getAlbum().getId())) {
                p.setAlbum(null);
            }
        }
        photoRepository.saveAll(photos);

        // 사진이 다 빠져버리면 썸네일도 비워 줌
        if (a.getPhotos() == null || a.getPhotos().isEmpty()) {
            a.setCoverPhotoUrl(null);
        }
    }

    /** 앨범 수정 */
    @Transactional
    public AlbumDetailResponse updateAlbum(Long userId, Long albumId, UpdateAlbumRequest req) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));
        if (a.getUser() == null || !userId.equals(a.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다.");
        }

        if (req.getTitle() != null) a.setName(req.getTitle());
        if (req.getDescription() != null) a.setDescription(req.getDescription());
        // coverPhotoId 는 별도 썸네일 API에서 처리

        return toDetail(a);
    }

    /** 앨범 삭제 */
    @Transactional
    public void deleteAlbum(Long userId, Long albumId) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));
        if (a.getUser() == null || !userId.equals(a.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다.");
        }
        albumRepository.delete(a);
    }

    // ========================================================
    // ✅ 썸네일 생성/지정 API 로직
    // ========================================================
    @Transactional
    public AlbumThumbnailResponse updateThumbnail(
            Long userId,
            Long albumId,
            Long photoId,
            MultipartFile file
    ) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        if (album.getUser() == null || !userId.equals(album.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다.");
        }

        String thumbnailUrl;

        // 1) 직접 업로드된 파일을 썸네일로 사용하는 경우
        if (file != null && !file.isEmpty()) {
            try {
                String key = photoStorage.store(file);          // S3 Key
                thumbnailUrl = toPublicUrl(key);               // /files/... 형태의 URL
            } catch (Exception e) {
                throw new ApiException(ErrorCode.STORAGE_FAILED,
                        "썸네일 파일 업로드 실패: " + e.getMessage(), e);
            }
        }
        // 2) 앨범 내 특정 사진을 썸네일로 지정
        else if (photoId != null) {
            Photo photo = photoRepository.findById(photoId)
                    .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "PHOTO_NOT_FOUND"));

            if (photo.getAlbum() == null || !albumId.equals(photo.getAlbum().getId())) {
                throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범의 사진이 아닙니다.");
            }

            thumbnailUrl = (photo.getThumbnailUrl() != null && !photo.getThumbnailUrl().isBlank())
                    ? photo.getThumbnailUrl()
                    : photo.getImageUrl();
        }
        // 3) 아무것도 안 들어온 경우: 자동 선택 (앨범 내 첫 사진 or 최신 사진)
        else {
            thumbnailUrl = pickAutoThumbnailUrl(album);
            if (thumbnailUrl == null) {
                throw new ApiException(ErrorCode.NOT_FOUND, "PHOTO_NOT_FOUND");
            }
        }

        album.setCoverPhotoUrl(thumbnailUrl);

        return new AlbumThumbnailResponse(
                album.getId(),
                thumbnailUrl,
                "앨범 썸네일이 성공적으로 설정되었습니다."
        );
    }

    // ========================================================
    // 내부 유틸 메서드들
    // ========================================================

    /** PhotoServiceImpl과 동일한 규칙으로 URL 생성 */
    private String toPublicUrl(String key) {
        if (key == null) return null;
        if (key.startsWith("http://") || key.startsWith("https://")) {
            return key;
        }
        return String.format("%s/files/%s", publicBaseUrl, key);
    }

    /** 앨범에 썸네일이 비어 있고 사진이 있으면 자동으로 채워 준다. */
    private void autoSetThumbnailIfMissing(Album album) {
        if (album.getCoverPhotoUrl() != null && !album.getCoverPhotoUrl().isBlank()) return;
        String url = pickAutoThumbnailUrl(album);
        album.setCoverPhotoUrl(url);
    }

    /** 앨범 내 사진 목록에서 자동 썸네일 선택 (가장 최신 createdAt 기준) */
    private String pickAutoThumbnailUrl(Album album) {
        if (album.getPhotos() == null || album.getPhotos().isEmpty()) return null;

        return album.getPhotos().stream()
                .filter(p -> Boolean.FALSE.equals(p.getDeleted()))
                .sorted(Comparator.comparing(Photo::getCreatedAt).reversed())
                .map(p -> (p.getThumbnailUrl() != null && !p.getThumbnailUrl().isBlank())
                        ? p.getThumbnailUrl()
                        : p.getImageUrl())
                .findFirst()
                .orElse(null);
    }

    /** 엔티티 → 요약 DTO */
    private AlbumSummaryResponse toSummary(Album a) {
        String coverUrl = (a.getCoverPhotoUrl() != null && !a.getCoverPhotoUrl().isBlank())
                ? a.getCoverPhotoUrl()
                : pickAutoThumbnailUrl(a);  // fallback

        int count = (a.getPhotos() == null) ? 0 : a.getPhotos().size();
        return new AlbumSummaryResponse(a.getId(), a.getName(), coverUrl, count, a.getCreatedAt());
    }

    /** 엔티티 → 상세 DTO */
    private AlbumDetailResponse toDetail(Album a) {
        List<Long> idList = (a.getPhotos() == null) ? List.of() :
                a.getPhotos().stream()
                        .map(Photo::getId)
                        .collect(Collectors.toList());

        List<PhotoResponseDto> list = (a.getPhotos() == null) ? List.of() :
                a.getPhotos().stream()
                        .map(PhotoResponseDto::new) // Photo 엔티티 기반 생성자 존재
                        .collect(Collectors.toList());

        String coverUrl = (a.getCoverPhotoUrl() != null && !a.getCoverPhotoUrl().isBlank())
                ? a.getCoverPhotoUrl()
                : pickAutoThumbnailUrl(a);

        int count = list.size();

        return new AlbumDetailResponse(
                a.getId(),
                a.getName(),
                a.getDescription(),
                coverUrl,
                count,
                a.getCreatedAt(),
                idList,
                list
        );
    }
}
