// backend/src/main/java/com/nemo/backend/domain/album/service/AlbumService.java
package com.nemo.backend.domain.album.service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

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
import com.nemo.backend.domain.photo.service.S3PhotoStorage;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

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
    // ownership: ALL / OWNED / SHARED
    public List<AlbumSummaryResponse> getAlbums(Long userId, AlbumOwnershipFilter ownership) {

        List<AlbumSummaryResponse> owned = albumRepository.findByUserId(userId).stream()
                .map(album -> {
                    autoSetThumbnailIfMissing(album);
                    int photoCount = (album.getPhotos() == null)
                            ? 0
                            : (int) album.getPhotos().stream()
                            .filter(p -> Boolean.FALSE.equals(p.getDeleted()))
                            .count();
                    return AlbumSummaryResponse.builder()
                            .albumId(album.getId())
                            .title(album.getName())
                            .coverPhotoUrl(album.getCoverPhotoUrl())
                            .photoCount(photoCount)
                            .createdAt(album.getCreatedAt())
                            .role("OWNER")
                            .build();
                })
                .collect(Collectors.toList());

        List<AlbumSummaryResponse> shared = albumShareRepository
                .findByUserIdAndStatusAndActiveTrue(userId, Status.ACCEPTED).stream()
                .map(share -> {
                    Album album = share.getAlbum();
                    autoSetThumbnailIfMissing(album);
                    int photoCount = (album.getPhotos() == null)
                            ? 0
                            : (int) album.getPhotos().stream()
                            .filter(p -> Boolean.FALSE.equals(p.getDeleted()))
                            .count();
                    return AlbumSummaryResponse.builder()
                            .albumId(album.getId())
                            .title(album.getName())
                            .coverPhotoUrl(album.getCoverPhotoUrl())
                            .photoCount(photoCount)
                            .createdAt(album.getCreatedAt())
                            .role(share.getRole().name())
                            .build();
                })
                .collect(Collectors.toList());

        List<AlbumSummaryResponse> result;

        switch (ownership) {
            case OWNED -> result = owned;
            case SHARED -> result = shared;
            case ALL -> {
                result = new ArrayList<>(owned);
                result.addAll(shared);
            }
            default -> throw new IllegalStateException("Unexpected value: " + ownership);
        }

        result.sort(Comparator.comparing(AlbumSummaryResponse::getCreatedAt).reversed());

        return result;
    }

    // favoriteOnly까지 포함
    public List<AlbumSummaryResponse> getAlbums(Long userId, String ownership, boolean favoriteOnly) {

        AlbumOwnershipFilter filter = AlbumOwnershipFilter.from(ownership);
        List<AlbumSummaryResponse> base = getAlbums(userId, filter);

        if (!favoriteOnly) {
            return base;
        }

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
            role = share.getRole().name();
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
            List<Photo> alivePhotos = photos.stream()
                    .filter(p -> Boolean.FALSE.equals(p.getDeleted()))
                    .toList();

            if (saved.getPhotos() == null) {
                saved.setPhotos(new ArrayList<>());
            }
            saved.getPhotos().addAll(alivePhotos);

            // 생성 시 사용자가 지정한 썸네일이 있으면 우선 적용 (photoIdList 안에 있는 경우)
            if (req.getCoverPhotoId() != null) {
                alivePhotos.stream()
                        .filter(p -> req.getCoverPhotoId().equals(p.getId()))
                        .findFirst()
                        .ifPresent(p -> {
                            String thumb = (p.getThumbnailUrl() != null && !p.getThumbnailUrl().isBlank())
                                    ? p.getThumbnailUrl()
                                    : p.getImageUrl();
                            saved.setCoverPhotoUrl(thumb);
                        });
            }
        }

        // photoIdList 가 비어 있어도 coverPhotoId 가 들어온 경우 한 번 더 커버 처리
        if (req.getCoverPhotoId() != null &&
                (saved.getCoverPhotoUrl() == null || saved.getCoverPhotoUrl().isBlank())) {

            photoRepository.findByIdAndDeletedIsFalse(req.getCoverPhotoId())
                    .ifPresent(p -> {
                        String thumb = (p.getThumbnailUrl() != null && !p.getThumbnailUrl().isBlank())
                                ? p.getThumbnailUrl()
                                : p.getImageUrl();
                        saved.setCoverPhotoUrl(thumb);

                        // 앨범에 아직 없는 사진이면 같이 추가
                        if (saved.getPhotos() == null) {
                            saved.setPhotos(new ArrayList<>());
                        }
                        boolean exists = saved.getPhotos().stream()
                                .anyMatch(existing -> existing.getId().equals(p.getId()));
                        if (!exists) {
                            saved.getPhotos().add(p);
                        }
                    });
        }

        // 최종적으로 커버가 비어 있으면 자동 썸네일
        autoSetThumbnailIfMissing(saved);

        return toDetail(saved, "OWNER");
    }

    // 4) 앨범에 사진 추가 / 제거
    @Transactional
    public int addPhotos(Long userId, Long albumId, List<Long> photoIdList) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        if (!canManagePhotos(userId, album)) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 사진을 추가할 권한이 없습니다.");
        }

        List<Photo> photos = photoRepository.findAllById(photoIdList);

        if (album.getPhotos() == null) {
            album.setPhotos(new ArrayList<>());
        }

        int count = 0;
        for (Photo p : photos) {
            if (Boolean.TRUE.equals(p.getDeleted())) {
                continue;
            }
            boolean alreadyExists = album.getPhotos().stream()
                    .anyMatch(existing -> existing.getId().equals(p.getId()));
            if (!alreadyExists) {
                album.getPhotos().add(p);
                count++;
            }
        }

        // 썸네일이 비어 있으면 자동 지정
        autoSetThumbnailIfMissing(album);
        return count;
    }

    @Transactional
    public int removePhotos(Long userId, Long albumId, List<Long> photoIdList) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        if (!canManagePhotos(userId, album)) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에서 사진을 삭제할 권한이 없습니다.");
        }

        if (album.getPhotos() == null || album.getPhotos().isEmpty()) {
            return 0;
        }

        Set<Long> targetIds = new HashSet<>(photoIdList);

        // 현재 썸네일이 삭제 대상인지 체크
        String currentCover = album.getCoverPhotoUrl();
        boolean coverWillBeRemoved = false;
        if (currentCover != null && !currentCover.isBlank()) {
            coverWillBeRemoved = album.getPhotos().stream()
                    .filter(p -> targetIds.contains(p.getId()))
                    .anyMatch(p -> {
                        String candidate = (p.getThumbnailUrl() != null && !p.getThumbnailUrl().isBlank())
                                ? p.getThumbnailUrl()
                                : p.getImageUrl();
                        return currentCover.equals(candidate);
                    });
        }

        int beforeSize = album.getPhotos().size();
        album.getPhotos().removeIf(p -> targetIds.contains(p.getId()));
        int count = beforeSize - album.getPhotos().size();

        // 남은 사진 기반 썸네일 처리
        if (album.getPhotos().isEmpty()) {
            album.setCoverPhotoUrl(null);
        } else if (coverWillBeRemoved) {
            album.setCoverPhotoUrl(null);
            autoSetThumbnailIfMissing(album);
        }

        return count;
    }

    // 5) 앨범 수정
    @Transactional
    public AlbumDetailResponse updateAlbum(Long userId, Long albumId, UpdateAlbumRequest req) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.ALBUM_NOT_FOUND, "ALBUM_NOT_FOUND"));

        // 소유자만 수정 가능 (명세 기준)
        if (album.getUser() == null || !userId.equals(album.getUser().getId())) {
            throw new ApiException(ErrorCode.ALBUM_FORBIDDEN, "해당 앨범을 수정할 권한이 없습니다.");
        }

        // 제목/설명 수정 (null 이면 변경 안 함)
        if (req.getTitle() != null) {
            album.setName(req.getTitle());
        }
        if (req.getDescription() != null) {
            album.setDescription(req.getDescription());
        }

        // coverPhotoId 가 들어온 경우 대표 사진 변경
        if (req.getCoverPhotoId() != null) {
            Long coverPhotoId = req.getCoverPhotoId();

            Photo photo = photoRepository.findByIdAndDeletedIsFalse(coverPhotoId)
                    .orElseThrow(() ->
                            new ApiException(ErrorCode.PHOTO_NOT_FOUND, "대표 사진으로 지정할 사진을 찾을 수 없습니다."));

            boolean inAlbum = album.getPhotos() != null &&
                    album.getPhotos().stream()
                            .filter(p -> Boolean.FALSE.equals(p.getDeleted()))
                            .anyMatch(p -> p.getId().equals(coverPhotoId));

            if (!inAlbum) {
                throw new ApiException(
                        ErrorCode.VALIDATION_FAILED,
                        "대표 사진은 해당 앨범에 포함된 사진만 지정할 수 있습니다."
                );
            }

            String thumb = (photo.getThumbnailUrl() != null && !photo.getThumbnailUrl().isBlank())
                    ? photo.getThumbnailUrl()
                    : photo.getImageUrl();
            album.setCoverPhotoUrl(thumb);
        }

        // coverPhotoId 안 들어온 경우: 비어 있으면 자동 썸네일 채우기
        if (req.getCoverPhotoId() == null) {
            autoSetThumbnailIfMissing(album);
        }

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
            album.getPhotos().clear();
        }

        albumRepository.delete(album);
    }

    // 6) 앨범 썸네일 생성/지정
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

        // 1) file 이 있으면 업로드한 이미지로 썸네일 지정
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
        }
        // 2) photoId 가 있으면 앨범 내 사진을 썸네일로 지정
        else if (photoId != null) {
            Photo photo = photoRepository.findByIdAndDeletedIsFalse(photoId)
                    .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "PHOTO_NOT_FOUND"));

            if (album.getPhotos() == null ||
                    album.getPhotos().stream().noneMatch(p -> p.getId().equals(photoId))) {
                throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범의 사진이 아닙니다.");
            }

            thumbnailUrl = (photo.getThumbnailUrl() != null && !photo.getThumbnailUrl().isBlank())
                    ? photo.getThumbnailUrl()
                    : photo.getImageUrl();
        }
        // 3) Body 비어 있으면 → 자동 지정
        else {
            thumbnailUrl = pickAutoThumbnailUrl(album);
            if (thumbnailUrl == null) {
                // 앨범에 살아있는 사진이 없는 경우
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

    // 8) 앨범 전체 사진 다운로드 URL 조회
    public AlbumDownloadUrlsResponse getAlbumDownloadUrls(Long userId, Long albumId) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        if (!canAccessAlbum(userId, album)) {
            throw new ApiException(ErrorCode.FORBIDDEN, "해당 앨범에 접근할 권한이 없습니다.");
        }

        List<Photo> photos = (album.getPhotos() == null)
                ? List.of()
                : album.getPhotos().stream()
                .filter(p -> Boolean.FALSE.equals(p.getDeleted()))
                .sorted(Comparator.comparing(Photo::getCreatedAt))
                .toList();

        int seq = 1;
        List<AlbumPhotoDownloadUrlDto> photoDtos = new ArrayList<>();

        for (Photo p : photos) {
            String downloadUrl = p.getImageUrl();
            String filename = buildDownloadFilename(p);
            Long fileSize = resolveFileSize(p);

            photoDtos.add(AlbumPhotoDownloadUrlDto.builder()
                    .photoId(p.getId())
                    .sequence(seq++)
                    .downloadUrl(downloadUrl)
                    .filename(filename)
                    .fileSize(fileSize)
                    .build());
        }

        return AlbumDownloadUrlsResponse.builder()
                .albumId(album.getId())
                .albumTitle(album.getName())
                .photoCount(photoDtos.size())
                .photos(photoDtos)
                .build();
    }

    // 내부 유틸
    private String toPublicUrl(String key) {
        if (key == null) return null;
        if (key.startsWith("http://") || key.startsWith("https://")) {
            return key;
        }
        return String.format("%s/files/%s", publicBaseUrl, key);
    }

    /** 앨범의 coverPhotoUrl 자동 설정 로직 */
    private void autoSetThumbnailIfMissing(Album album) {

        // 살아있는 사진이 하나도 없으면 썸네일 제거
        boolean hasAlivePhoto = album.getPhotos() != null &&
                album.getPhotos().stream()
                        .anyMatch(p -> Boolean.FALSE.equals(p.getDeleted()));

        if (!hasAlivePhoto) {
            album.setCoverPhotoUrl(null);
            return;
        }

        // coverPhotoUrl 이 비어 있을 때만 자동으로 채움
        if (album.getCoverPhotoUrl() == null || album.getCoverPhotoUrl().isBlank()) {
            album.setCoverPhotoUrl(pickAutoThumbnailUrl(album));
        }
        // 이미 값이 있으면 (사용자 지정/업로드) 건드리지 않음
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

    /** imageUrl → S3 key 추출 */
    private String extractStorageKeyFromUrl(String url) {
        if (url == null || url.isBlank()) return null;

        String base = publicBaseUrl.replaceAll("/+$", "");
        if (!url.startsWith(base)) {
            return null;
        }

        String path = url.substring(base.length()); // "/files/..."
        if (!path.startsWith("/files/")) {
            return null;
        }
        return path.substring("/files/".length());
    }

    /** photo.imageUrl 기준 파일 크기 조회 */
    private Long resolveFileSize(Photo photo) {
        String key = extractStorageKeyFromUrl(photo.getImageUrl());
        if (key == null) return null;

        if (photoStorage instanceof S3PhotoStorage s3) {
            try {
                return s3.getObjectSize(key);
            } catch (Exception e) {
                return null;
            }
        }
        return null;
    }

    /** 다운로드용 파일 이름 생성 */
    private String buildDownloadFilename(Photo photo) {
        String url = photo.getImageUrl();
        String ext = "jpg";
        if (url != null) {
            try {
                String path = new java.net.URL(url).getPath();
                String name = path.substring(path.lastIndexOf('/') + 1);
                int dot = name.lastIndexOf('.');
                if (dot > 0 && dot < name.length() - 1) {
                    ext = name.substring(dot + 1);
                }
            } catch (Exception ignored) {}
        }
        return "nemo_photo_" + photo.getId() + "." + ext;
    }

}
