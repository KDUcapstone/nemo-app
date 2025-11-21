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
    private final AlbumFavoriteRepository albumFavoriteRepository;
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

    // 1) 앨범 목록 조회 (ownership + favoriteOnly)
    public List<AlbumSummaryResponse> getAlbums(Long userId, String ownership) {
        // enum으로 정규화
        AlbumOwnershipFilter filter = AlbumOwnershipFilter.from(ownership);

        // 1) 내가 만든 앨범
        List<AlbumSummaryResponse> owned = albumRepository.findByUserId(userId).stream()
                .map(album -> {
                    autoSetThumbnailIfMissing(album);
                    int photoCount = (album.getPhotos() == null) ? 0 : album.getPhotos().size();
                    return AlbumSummaryResponse.builder()
                            .albumId(album.getId())
                            .title(album.getName())
                            .coverPhotoUrl(album.getCoverPhotoUrl())
                            .photoCount(photoCount)
                            .createdAt(album.getCreatedAt())
                            .role("OWNER")
                            .build();
                })
                .toList();

        // 2) 내가 공유받은 앨범 (ACCEPTED + active)
        List<AlbumSummaryResponse> shared = albumShareRepository
                .findByUserIdAndStatusAndActiveTrue(userId, Status.ACCEPTED).stream()
                .map(share -> {
                    Album album = share.getAlbum();
                    autoSetThumbnailIfMissing(album);
                    int photoCount = (album.getPhotos() == null) ? 0 : album.getPhotos().size();
                    return AlbumSummaryResponse.builder()
                            .albumId(album.getId())
                            .title(album.getName())
                            .coverPhotoUrl(album.getCoverPhotoUrl())
                            .photoCount(photoCount)
                            .createdAt(album.getCreatedAt())
                            .role(share.getRole().name()) // VIEWER / EDITOR / CO_OWNER
                            .build();
                })
                .toList();

        List<AlbumSummaryResponse> base;

        switch (filter) {
            case OWNED -> base = owned;
            case SHARED -> base = shared;
            case ALL -> {
                owned.addAll(shared);
                base = owned;
            }
            default -> base = owned;
        }

        // 최신 생성순 정렬 (명세에서 sort=createdAt,desc 기본)
        return base.stream()
                .sorted(Comparator.comparing(AlbumSummaryResponse::getCreatedAt).reversed())
                .toList();
    }

    // favoriteOnly까지 포함
    public List<AlbumSummaryResponse> getAlbums(Long userId, String ownership, boolean favoriteOnly) {
        List<AlbumSummaryResponse> base = getAlbums(userId, ownership);

        if (!favoriteOnly) {
            return base;
        }

        // 내가 즐겨찾기한 앨범 ID 목록
        Set<Long> favIds = albumFavoriteRepository.findByUserId(userId).stream()
                .map(f -> f.getAlbum().getId())
                .collect(Collectors.toSet());

        return base.stream()
                .filter(a -> favIds.contains(a.getAlbumId()))
                .toList();
    }

    // 2) 앨범 상세 조회
    public AlbumDetailResponse getAlbum(Long userId, Long albumId) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        String role;
        if (album.getUser() != null && userId.equals(album.getUser().getId())) {
            role = "OWNER";
        } else {
            AlbumShare share = albumShareRepository
                    .findByAlbumIdAndUserIdAndStatusAndActiveTrue(albumId, userId, Status.ACCEPTED)
                    .orElseThrow(() -> new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다."));
            role = share.getRole().name(); // VIEWER / EDITOR / CO_OWNER
        }

        autoSetThumbnailIfMissing(album);
        return toDetail(album, role);
    }

    // 3) 앨범 생성
    @Transactional
    public AlbumDetailResponse createAlbum(Long userId, CreateAlbumRequest req) {
        if (req.getTitle() == null || req.getTitle().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "앨범 이름(title)은 필수입니다.");
        }

        Album album = new Album();
        album.setName(req.getTitle());
        album.setDescription(req.getDescription());

        User ownerRef = em.getReference(User.class, userId);
        album.setUser(ownerRef);

        Album saved = albumRepository.save(album);

        // 초기 사진 지정
        if (req.getPhotoIdList() != null && !req.getPhotoIdList().isEmpty()) {
            List<Photo> photos = photoRepository.findAllById(req.getPhotoIdList());
            for (Photo p : photos) {
                p.setAlbum(saved);
            }
            photoRepository.saveAll(photos);
            saved.setPhotos(photos);
        }

        autoSetThumbnailIfMissing(saved);

        return toDetail(saved, "OWNER");
    }

    // 4) 앨범에 사진 추가 / 제거
    @Transactional
    public int addPhotos(Long userId, Long albumId, List<Long> photoIds) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        if (!canManagePhotos(userId, album)) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 사진을 추가할 권한이 없습니다.");
        }

        List<Photo> photos = photoRepository.findAllById(photoIds);
        int count = 0;
        for (Photo p : photos) {
            if (p.getAlbum() == null || !albumId.equals(p.getAlbum().getId())) {
                p.setAlbum(album);
                count++;
            }
        }
        photoRepository.saveAll(photos);

        autoSetThumbnailIfMissing(album);
        return count;
    }

    @Transactional
    public int removePhotos(Long userId, Long albumId, List<Long> photoIds) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        if (!canManagePhotos(userId, album)) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에서 사진을 삭제할 권한이 없습니다.");
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

        if (album.getPhotos() == null || album.getPhotos().isEmpty()) {
            album.setCoverPhotoUrl(null);
        }

        return count;
    }

    // 5) 앨범 수정 / 삭제
    @Transactional
    public AlbumDetailResponse updateAlbum(Long userId, Long albumId, UpdateAlbumRequest req) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        if (album.getUser() == null || !userId.equals(album.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범을 수정할 권한이 없습니다.");
        }

        if (req.getTitle() != null) album.setName(req.getTitle());
        if (req.getDescription() != null) album.setDescription(req.getDescription());

        autoSetThumbnailIfMissing(album);
        return toDetail(album, "OWNER");
    }

    @Transactional
    public void deleteAlbum(Long userId, Long albumId) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        if (album.getUser() == null || !userId.equals(album.getUser().getId())) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범을 삭제할 권한이 없습니다.");
        }

        if (album.getPhotos() != null && !album.getPhotos().isEmpty()) {
            album.getPhotos().forEach(photo -> photo.setAlbum(null));
            photoRepository.saveAll(album.getPhotos());
        }

        albumRepository.delete(album);
    }

    // 6) 썸네일 설정
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

        if (file != null && !file.isEmpty()) {
            try {
                String key = photoStorage.store(file);
                thumbnailUrl = toPublicUrl(key);
            } catch (Exception e) {
                throw new ApiException(
                        ErrorCode.STORAGE_FAILED,
                        "썸네일 파일 업로드 실패: " + e.getMessage(),
                        e
                );
            }
        } else if (photoId != null) {
            Photo photo = photoRepository.findById(photoId)
                    .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "PHOTO_NOT_FOUND"));

            if (photo.getAlbum() == null || !albumId.equals(photo.getAlbum().getId())) {
                throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범의 사진이 아닙니다.");
            }

            thumbnailUrl = (photo.getThumbnailUrl() != null && !photo.getThumbnailUrl().isBlank())
                    ? photo.getThumbnailUrl()
                    : photo.getImageUrl();
        } else {
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

    // 7) 즐겨찾기
    private boolean canAccessAlbum(Long userId, Album album) {
        if (album.getUser() != null && userId.equals(album.getUser().getId())) {
            return true;
        }

        return albumShareRepository
                .findByAlbumIdAndUserIdAndStatusAndActiveTrue(album.getId(), userId, Status.ACCEPTED)
                .isPresent();
    }

    private boolean canManagePhotos(Long userId, Album album) {
        if (album.getUser() != null && userId.equals(album.getUser().getId())) {
            return true;
        }

        return albumShareRepository
                .findByAlbumIdAndUserIdAndStatusAndActiveTrue(album.getId(), userId, Status.ACCEPTED)
                .map(AlbumShare::getRole)
                .map(role -> role == AlbumShare.Role.EDITOR || role == AlbumShare.Role.CO_OWNER)
                .orElse(false);
    }

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

    // 내부 유틸
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

    private AlbumDetailResponse toDetail(Album album, String role) {
        List<AlbumDetailResponse.PhotoSummary> photoList =
                (album.getPhotos() == null) ? List.of() :
                        album.getPhotos().stream()
                                .filter(p -> Boolean.FALSE.equals(p.getDeleted()))
                                .map(p -> new AlbumDetailResponse.PhotoSummary(
                                        p.getId(),
                                        p.getImageUrl(),
                                        p.getTakenAt(),
                                        p.getLocation(),
                                        p.getBrand()
                                ))
                                .toList();

        int photoCount = photoList.size();

        return AlbumDetailResponse.builder()
                .albumId(album.getId())
                .title(album.getName())
                .description(album.getDescription())
                .coverPhotoUrl(album.getCoverPhotoUrl())
                .photoCount(photoCount)
                .createdAt(album.getCreatedAt())
                .role(role)
                .photoList(photoList)
                .build();
    }
}
