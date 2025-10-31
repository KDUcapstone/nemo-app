// backend/src/main/java/com/nemo/backend/domain/album/service/AlbumService.java
package com.nemo.backend.domain.album.service;

import java.util.List;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.repository.AlbumRepository;
import com.nemo.backend.domain.photo.dto.PhotoResponse;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.domain.photo.repository.PhotoRepository;

@Service
@Transactional(readOnly = true)
public class AlbumService {

    private final AlbumRepository albumRepository;
    private final PhotoRepository photoRepository;

    public AlbumService(AlbumRepository albumRepository, PhotoRepository photoRepository) {
        this.albumRepository = albumRepository;
        this.photoRepository = photoRepository;
    }

    public List<AlbumSummaryResponse> getAlbums() {
        return albumRepository.findAll().stream().map(this::toSummary).collect(Collectors.toList());
    }

    public AlbumDetailResponse getAlbum(Long albumId) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new IllegalArgumentException("ALBUM_NOT_FOUND"));
        return toDetail(a);
    }

    @Transactional
    public AlbumDetailResponse createAlbum(CreateAlbumRequest req) {
        Album a = new Album();
        a.setName(req.getTitle());          // 엔티티의 name ← 프론트의 title
        a.setDescription(req.getDescription());
        Album saved = albumRepository.save(a);

        if (req.getPhotoIdList() != null && !req.getPhotoIdList().isEmpty()) {
            List<Photo> photos = photoRepository.findAllById(req.getPhotoIdList());
            for (Photo p : photos) { p.setAlbum(saved); }
        }
        return toDetail(saved);
    }

    @Transactional
    public void addPhotos(Long albumId, List<Long> photoIds) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new IllegalArgumentException("ALBUM_NOT_FOUND"));
        List<Photo> photos = photoRepository.findAllById(photoIds);
        for (Photo p : photos) { p.setAlbum(a); }
    }

    @Transactional
    public void removePhotos(Long albumId, List<Long> photoIds) {
        List<Photo> photos = photoRepository.findAllById(photoIds);
        for (Photo p : photos) {
            if (p.getAlbum() != null && albumId.equals(p.getAlbum().getId())) {
                p.setAlbum(null);
            }
        }
    }

    @Transactional
    public AlbumDetailResponse updateAlbum(Long albumId, UpdateAlbumRequest req) {
        Album a = albumRepository.findById(albumId)
                .orElseThrow(() -> new IllegalArgumentException("ALBUM_NOT_FOUND"));
        if (req.getTitle() != null) a.setName(req.getTitle());
        if (req.getDescription() != null) a.setDescription(req.getDescription());
        // coverPhotoId → coverPhotoUrl 매핑은 추가 구현 필요
        return toDetail(a);
    }

    @Transactional
    public void deleteAlbum(Long albumId) {
        albumRepository.deleteById(albumId);
    }

    private AlbumSummaryResponse toSummary(Album a) {
        String coverUrl = (a.getPhotos() != null && !a.getPhotos().isEmpty())
                ? a.getPhotos().get(0).getImageUrl() : null;
        int count = (a.getPhotos() == null) ? 0 : a.getPhotos().size();
        return new AlbumSummaryResponse(a.getId(), a.getName(), coverUrl, count, a.getCreatedAt());
    }

    private AlbumDetailResponse toDetail(Album a) {
        List<Long> idList = (a.getPhotos() == null) ? List.of() :
                a.getPhotos().stream().map(Photo::getId).collect(Collectors.toList());

        List<PhotoResponse> list = (a.getPhotos() == null) ? List.of() :
                a.getPhotos().stream().map(p ->
                        new PhotoResponse(
                                p.getId(),
                                p.getImageUrl(),
                                p.getTakenAt(),
                                // ✅ 수정: getLocation() 대신 locationId를 문자열로 변환하여 전달
                                (p.getLocationId() != null ? p.getLocationId().toString() : null),
                                p.getBrand()
                        )
                ).collect(Collectors.toList());

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
