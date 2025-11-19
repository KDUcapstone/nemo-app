// backend/src/main/java/com/nemo/backend/domain/album/service/AlbumService.java
package com.nemo.backend.domain.album.service;

import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.entity.AlbumShare;
import com.nemo.backend.domain.album.entity.AlbumShare.Status;
import com.nemo.backend.domain.album.entity.AlbumFavorite;
import com.nemo.backend.domain.album.repository.AlbumFavoriteRepository;
import com.nemo.backend.domain.album.repository.AlbumRepository;
import com.nemo.backend.domain.album.repository.AlbumShareRepository;
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
    private final AlbumShareRepository albumShareRepository;
    private final PhotoRepository photoRepository;
    private final AlbumFavoriteRepository albumFavoriteRepository; // ✅ 즐겨찾기 리포지토리
    private final PhotoStorage photoStorage;

    private final String publicBaseUrl;

    @PersistenceContext
    private EntityManager em;

    public AlbumService(
            AlbumRepository albumRepository,
            AlbumShareRepository albumShareRepository,
            PhotoRepository photoRepository,
            AlbumFavoriteRepository albumFavoriteRepository,
            PhotoStorage photoStorage,
            @Value("${app.public-base-url:http://localhost:8080}") String publicBaseUrl
    ) {
        this.albumRepository = albumRepository;
        this.albumShareRepository = albumShareRepository;
        this.photoRepository = photoRepository;
        this.albumFavoriteRepository = albumFavoriteRepository;
        this.photoStorage = photoStorage;
        this.publicBaseUrl = publicBaseUrl.replaceAll("/+$", "");
    }

    /**
     * 로그인 사용자의 앨범 목록 조회 (명세: ownership = ALL/OWNED/SHARED)
     */
    public List<AlbumSummaryResponse> getAlbums(Long userId, String ownership) {
        // 1) 내가 만든 앨범
        List<AlbumSummaryResponse> owned = albumRepository.findAll().stream()
                .filter(a -> a.getUser() != null && userId.equals(a.getUser().getId()))
                .map(a -> toSummary(a, "OWNER"))
                .collect(Collectors.toList());

        // 2) 내가 공유받은 앨범 (ACCEPTED + active)
        List<AlbumSummaryResponse> shared = albumShareRepository
                .findByUserIdAndStatusAndActiveTrue(userId, Status.ACCEPTED).stream()
                .map(share -> {
                    Album a = share.getAlbum();
                    String role = share.getRole().name(); // VIEWER / EDITOR / CO_OWNER
                    return toSummary(a, role);
                })
                .collect(Collectors.toList());

        if ("OWNED".equalsIgnoreCase(ownership)) {
            return owned;
        } else if ("SHARED".equalsIgnoreCase(ownership)) {
            return shared;
        } else { // ALL (기본값)
            owned.addAll(shared);
            return owned;
        }
    }

    /**
     * 로그인 사용자의 앨범 목록 조회 + favoriteOnly 필터
     */
    public List<AlbumSummaryResponse> getAlbums(Long userId, String ownership, boolean favoriteOnly) {
        List<AlbumSummaryResponse> base = getAlbums(userId, ownership);

        if (!favoriteOnly) {
            return base;
        }

        // ✅ 내가 즐겨찾기한 앨범 ID 목록
        Set<Long> favIds = albumFavoriteRepository.findByUserId(userId).stream()
                .map(f -> f.getAlbum().getId())
                .collect(Collectors.toSet());

        return base.stream()
                .filter(a -> favIds.contains(a.getAlbumId()))
                .collect(Collectors.toList());
    }

    /**
     * 특정 앨범 상세 조회 (소유자 + 공유받은 사용자까지)
     */
    public AlbumDetailResponse getAlbum(Long userId, Long albumId) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        String role;

        if (a.getUser() != null && userId.equals(a.getUser().getId())) {
            role = "OWNER";
        } else {
            AlbumShare share = albumShareRepository
                    .findByAlbumIdAndUserIdAndStatusAndActiveTrue(albumId, userId, Status.ACCEPTED)
                    .orElseThrow(() -> new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다."));
            role = share.getRole().name(); // VIEWER / EDITOR / CO_OWNER
        }

        return toDetail(a, role);
    }

    /**
     * 앨범 생성
     */
    @Transactional
    public AlbumDetailResponse createAlbum(Long userId, CreateAlbumRequest req) {
        if (req.getTitle() == null || req.getTitle().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "앨범 이름(title)은 필수입니다.");
        }

        Album a = new Album();
        a.setName(req.getTitle());
        a.setDescription(req.getDescription());

        User ownerRef = em.getReference(User.class, userId);
        a.setUser(ownerRef);

        Album saved = albumRepository.save(a);

        if (req.getPhotoIds() != null && !req.getPhotoIds().isEmpty()) {
            List<Photo> photos = photoRepository.findAllById(req.getPhotoIds());
            for (Photo p : photos) {
                p.setAlbum(saved);
            }
            photoRepository.saveAll(photos);
            saved.setPhotos(photos);
        }

        autoSetThumbnailIfMissing(saved);

        // 생성 직후에는 항상 OWNER
        return toDetail(saved, "OWNER");
    }

    /**
     * 앨범에 사진 추가
     * @return 실제 추가된 사진 수
     */
    @Transactional
    public int addPhotos(Long userId, Long albumId, List<Long> photoIds) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));
        if (a.getUser() == null || !userId.equals(a.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다.");
        }

        List<Photo> photos = photoRepository.findAllById(photoIds);
        int count = 0;
        for (Photo p : photos) {
            if (p.getAlbum() == null || !albumId.equals(p.getAlbum().getId())) {
                p.setAlbum(a);
                count++;
            }
        }
        photoRepository.saveAll(photos);

        autoSetThumbnailIfMissing(a);

        return count;
    }

    /**
     * 앨범에서 사진 제거
     * @return 실제 제거된 사진 수
     */
    @Transactional
    public int removePhotos(Long userId, Long albumId, List<Long> photoIds) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));
        if (a.getUser() == null || !userId.equals(a.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다.");
        }

        List<Photo> photos = photoRepository.findAllById(photoIds);
        int count = 0;
        for (Photo p : photos) {
            if (p.getAlbum() != null && albumId.equals(p.getAlbum().getId())) {
                p.setAlbum(null);
                count++;
            }
        }
        photoRepository.saveAll(photos);

        if (a.getPhotos() == null || a.getPhotos().isEmpty()) {
            a.setCoverPhotoUrl(null);
        }

        return count;
    }

    /**
     * 앨범 수정
     */
    @Transactional
    public AlbumDetailResponse updateAlbum(Long userId, Long albumId, UpdateAlbumRequest req) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));
        if (a.getUser() == null || !userId.equals(a.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다.");
        }

        if (req.getTitle() != null) a.setName(req.getTitle());
        if (req.getDescription() != null) a.setDescription(req.getDescription());

        return toDetail(a, "OWNER");
    }

    /**
     * 앨범 삭제
     */
    @Transactional
    public void deleteAlbum(Long userId, Long albumId) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));
        if (a.getUser() == null || !userId.equals(a.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범을 삭제할 권한이 없습니다.");
        }

        // ✅ 1) 앨범-사진 관계만 끊기 (사진 레코드는 그대로 유지)
        if (a.getPhotos() != null && !a.getPhotos().isEmpty()) {
            a.getPhotos().forEach(photo -> photo.setAlbum(null));
            photoRepository.saveAll(a.getPhotos());
        }

        // ✅ 2) 그 다음 앨범만 삭제
        albumRepository.delete(a);
    }

    // ===== 썸네일 로직은 기존 그대로 =====

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

    // ===== 즐겨찾기 관련 유틸 =====

    /** OWNER 또는 공유 수락 멤버인지 확인 */
    private boolean canAccessAlbum(Long userId, Album album) {
        // OWNER
        if (album.getUser() != null && userId.equals(album.getUser().getId())) {
            return true;
        }

        // 공유 멤버 (ACCEPTED + active)
        return albumShareRepository
                .findByAlbumIdAndUserIdAndStatusAndActiveTrue(album.getId(), userId, Status.ACCEPTED)
                .isPresent();
    }

    /**
     * 즐겨찾기 설정/해제 공통 메서드
     */
    @Transactional
    public AlbumFavoriteResponse setFavorite(Long userId, Long albumId, boolean favorite) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        if (!canAccessAlbum(userId, album)) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다.");
        }

        boolean exists = albumFavoriteRepository.existsByAlbumIdAndUserId(albumId, userId);

        if (favorite) {
            if (!exists) {
                User userRef = em.getReference(User.class, userId);
                AlbumFavorite fav = AlbumFavorite.builder()
                        .album(album)
                        .user(userRef)
                        .build();
                albumFavoriteRepository.save(fav);
            }
            return AlbumFavoriteResponse.builder()
                    .albumId(albumId)
                    .favorited(true)
                    .message("앨범이 즐겨찾기에 추가되었습니다.")
                    .build();
        } else {
            if (exists) {
                albumFavoriteRepository.deleteByAlbumIdAndUserId(albumId, userId);
            }
            return AlbumFavoriteResponse.builder()
                    .albumId(albumId)
                    .favorited(false)
                    .message("앨범 즐겨찾기가 해제되었습니다.")
                    .build();
        }
    }

    // ===== 내부 유틸 =====

    private String toPublicUrl(String key) {
        if (key == null) return null;
        if (key.startsWith("http://") || key.startsWith("https://")) {
            return key;
        }
        return String.format("%s/files/%s", publicBaseUrl, key);
    }

    private void autoSetThumbnailIfMissing(Album album) {
        if (album.getCoverPhotoUrl() != null && !album.getCoverPhotoUrl().isBlank()) return;
        String url = pickAutoThumbnailUrl(album);
        album.setCoverPhotoUrl(url);
    }

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

    private AlbumSummaryResponse toSummary(Album a, String role) {
        String coverUrl = (a.getCoverPhotoUrl() != null && !a.getCoverPhotoUrl().isBlank())
                ? a.getCoverPhotoUrl()
                : pickAutoThumbnailUrl(a);

        int count = (a.getPhotos() == null) ? 0 : a.getPhotos().size();
        return AlbumSummaryResponse.builder()
                .albumId(a.getId())
                .title(a.getName())
                .coverPhotoUrl(coverUrl)
                .photoCount(count)
                .createdAt(a.getCreatedAt())
                .role(role)
                .build();
    }

    private AlbumDetailResponse toDetail(Album a, String role) {
        List<Long> idList = (a.getPhotos() == null) ? List.of() :
                a.getPhotos().stream()
                        .map(Photo::getId)
                        .collect(Collectors.toList());

        List<PhotoResponseDto> list = (a.getPhotos() == null) ? List.of() :
                a.getPhotos().stream()
                        .map(PhotoResponseDto::new)
                        .collect(Collectors.toList());

        String coverUrl = (a.getCoverPhotoUrl() != null && !a.getCoverPhotoUrl().isBlank())
                ? a.getCoverPhotoUrl()
                : pickAutoThumbnailUrl(a);

        int count = list.size();

        return AlbumDetailResponse.builder()
                .albumId(a.getId())
                .title(a.getName())
                .description(a.getDescription())
                .coverPhotoUrl(coverUrl)
                .photoCount(count)
                .createdAt(a.getCreatedAt())
                .role(role)
                .photoIdList(idList)
                .photoList(list)
                .build();
    }
}
