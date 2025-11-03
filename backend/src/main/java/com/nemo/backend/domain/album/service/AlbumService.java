// backend/src/main/java/com/nemo/backend/domain/album/service/AlbumService.java
package com.nemo.backend.domain.album.service;

import java.util.List;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.repository.AlbumRepository;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.domain.photo.repository.PhotoRepository;
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

    @PersistenceContext
    private EntityManager em;

    public AlbumService(AlbumRepository albumRepository, PhotoRepository photoRepository) {
        this.albumRepository = albumRepository;
        this.photoRepository = photoRepository;
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

        if (req.getPhotoIds() != null && !req.getPhotoIds().isEmpty()) {
            List<Photo> photos = photoRepository.findAllById(req.getPhotoIds());
            for (Photo p : photos) {
                p.setAlbum(saved);
            }
            photoRepository.saveAll(photos);
        }

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
        // coverPhotoId는 별도 처리 (추가 구현 가능)

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

    /** 엔티티 → 요약 DTO */
    private AlbumSummaryResponse toSummary(Album a) {
        String coverUrl = (a.getPhotos() != null && !a.getPhotos().isEmpty())
                ? a.getPhotos().get(0).getImageUrl()
                : null;
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

        String coverUrl = list.isEmpty() ? null : list.get(0).getImageUrl();
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
