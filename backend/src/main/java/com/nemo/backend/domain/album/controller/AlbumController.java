// backend/src/main/java/com/nemo/backend/domain/album/controller/AlbumController.java
package com.nemo.backend.domain.album.controller;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.service.AlbumService;
import com.nemo.backend.domain.auth.util.AuthExtractor;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping(
        value = "/api/albums",
        produces = "application/json; charset=UTF-8"
)
@RequiredArgsConstructor
public class AlbumController {

    private final AlbumService albumService;
    private final AuthExtractor authExtractor;

    // 1) GET /api/albums : 앨범 목록 조회
    @GetMapping
    public ResponseEntity<Map<String, Object>> getAlbums(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @RequestParam(value = "sort", defaultValue = "createdAt,desc") String sort,
            @RequestParam(value = "page", defaultValue = "0") int page,
            @RequestParam(value = "size", defaultValue = "10") int size,
            @RequestParam(value = "favoriteOnly", defaultValue = "false") boolean favoriteOnly,
            @RequestParam(value = "ownership", defaultValue = "ALL") String ownership
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        // favoriteOnly + ownership 반영
        List<AlbumSummaryResponse> all =
                new ArrayList<>(albumService.getAlbums(userId, ownership, favoriteOnly));

        // ===== 정렬 적용 =====
        String field = "createdAt";
        boolean asc = false; // default = 최신순 (desc)

        if (sort != null && !sort.isBlank()) {
            String[] parts = sort.split(",");
            field = parts[0].trim();
            if (parts.length > 1) {
                asc = "asc".equalsIgnoreCase(parts[1].trim());
            }
        }

        Comparator<AlbumSummaryResponse> comparator;

        switch (field) {
            case "title", "name" -> {
                comparator = Comparator.comparing(
                        AlbumSummaryResponse::getTitle,
                        String.CASE_INSENSITIVE_ORDER
                );
            }
            case "createdAt" -> {
                comparator = Comparator.comparing(AlbumSummaryResponse::getCreatedAt);
            }
            default -> {
                // 잘못된 필드가 들어오면 createdAt 기준으로
                comparator = Comparator.comparing(AlbumSummaryResponse::getCreatedAt);
            }
        }

        if (!asc) {
            comparator = comparator.reversed();
        }
        all.sort(comparator);
        // ===== 정렬 끝 =====

        int fromIndex = Math.max(page * size, 0);
        if (fromIndex > all.size()) {
            fromIndex = all.size();
        }
        int toIndex = Math.min(fromIndex + size, all.size());
        List<AlbumSummaryResponse> content = all.subList(fromIndex, toIndex);

        int totalElements = all.size();
        int totalPages = (int) Math.ceil(totalElements / (double) size);

        Map<String, Object> pageInfo = Map.of(
                "size", size,
                "totalElements", totalElements,
                "totalPages", totalPages,
                "number", page
        );

        return ResponseEntity.ok(
                Map.of(
                        "content", content,
                        "page", pageInfo
                )
        );
    }


    // 2) POST /api/albums : 앨범 생성
    @PostMapping
    public ResponseEntity<AlbumCreatedResponse> create(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @Valid @RequestBody CreateAlbumRequest req
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        AlbumDetailResponse detail = albumService.createAlbum(userId, req);
        AlbumCreatedResponse resp = AlbumCreatedResponse.from(detail);

        return ResponseEntity.status(201).body(resp);
    }

    // 3) GET /api/albums/{albumId} : 앨범 상세 조회
    @GetMapping("/{albumId}")
    public ResponseEntity<AlbumDetailResponse> get(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);
        AlbumDetailResponse resp = albumService.getAlbum(userId, albumId);
        return ResponseEntity.ok(resp);
    }

    // 4) PUT /api/albums/{albumId} : 앨범 정보 수정
    @PutMapping("/{albumId}")
    public ResponseEntity<AlbumUpdateResponse> update(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable long albumId,
            @RequestBody UpdateAlbumRequest req
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        AlbumDetailResponse updated = albumService.updateAlbum(userId, albumId, req);

        AlbumUpdateResponse resp = AlbumUpdateResponse.builder()
                .albumId(updated.getAlbumId())
                .message("앨범 정보가 성공적으로 수정되었습니다.")
                .build();

        return ResponseEntity.ok(resp);
    }

    // 5) POST /api/albums/{albumId}/photos : 사진 여러 장 추가
    @PostMapping("/{albumId}/photos")
    public ResponseEntity<AlbumPhotosAddResponse> addPhotos(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId,
            @Valid @RequestBody PhotoIdListRequest req
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);
        int added = albumService.addPhotos(userId, albumId, req.getPhotoIdList());

        AlbumPhotosAddResponse resp = AlbumPhotosAddResponse.builder()
                .albumId(albumId)
                .addedCount(added)
                .message("사진이 앨범에 추가되었습니다.")
                .build();

        return ResponseEntity.ok(resp);
    }

    // 6) DELETE /api/albums/{albumId}/photos : 사진 여러 장 삭제
    @DeleteMapping("/{albumId}/photos")
    public ResponseEntity<AlbumPhotosDeleteResponse> removePhotos(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId,
            @Valid @RequestBody PhotoIdListRequest req
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);
        int deleted = albumService.removePhotos(userId, albumId, req.getPhotoIdList());

        AlbumPhotosDeleteResponse resp = AlbumPhotosDeleteResponse.builder()
                .albumId(albumId)
                .deletedCount(deleted)
                .message("사진이 앨범에서 삭제되었습니다.")
                .build();

        return ResponseEntity.ok(resp);
    }

    // 7) DELETE /api/albums/{albumId} : 앨범 삭제
    @DeleteMapping("/{albumId}")
    public ResponseEntity<AlbumDeleteResponse> delete(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);
        albumService.deleteAlbum(userId, albumId);

        AlbumDeleteResponse resp = AlbumDeleteResponse.builder()
                .albumId(albumId)
                .message("앨범이 성공적으로 삭제되었습니다.")
                .build();

        return ResponseEntity.ok(resp);
    }

    // 8-1) POST /api/albums/{albumId}/thumbnail (JSON)
    @PostMapping(
            value = "/{albumId}/thumbnail",
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public ResponseEntity<AlbumThumbnailResponse> updateThumbnailFromGallery(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId,
            @RequestBody(required = false) AlbumThumbnailSelectRequest req   // ✅ optional
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        Long photoId = (req != null ? req.getPhotoId() : null);  // ✅ null 허용
        AlbumThumbnailResponse resp =
                albumService.updateThumbnail(userId, albumId, photoId, null);

        return ResponseEntity.ok(resp);
    }


    // 8-2) POST /api/albums/{albumId}/thumbnail (Multipart, 파일 업로드)
    @PostMapping(
            value = "/{albumId}/thumbnail",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public ResponseEntity<AlbumThumbnailResponse> updateThumbnailFromFile(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId,
            @RequestPart(value = "file", required = false) MultipartFile file   // ✅ optional
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);

        AlbumThumbnailResponse resp =
                albumService.updateThumbnail(userId, albumId, null, file);

        return ResponseEntity.ok(resp);
    }



    // 9) POST /api/albums/{albumId}/favorite : 앨범 즐겨찾기 추가
    @PostMapping("/{albumId}/favorite")
    public ResponseEntity<AlbumFavoriteResponse> addFavorite(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);
        AlbumFavoriteResponse resp = albumService.setFavorite(userId, albumId, true);
        return ResponseEntity.ok(resp);
    }

    // 10) DELETE /api/albums/{albumId}/favorite : 앨범 즐겨찾기 해제
    @DeleteMapping("/{albumId}/favorite")
    public ResponseEntity<AlbumFavoriteResponse> removeFavorite(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);
        AlbumFavoriteResponse resp = albumService.setFavorite(userId, albumId, false);
        return ResponseEntity.ok(resp);
    }

    // ✅ 11) GET /api/albums/{albumId}/download-urls : 앨범 전체 사진 다운로드 URL 목록
    @GetMapping("/{albumId}/download-urls")
    public ResponseEntity<AlbumDownloadUrlsResponse> getAlbumDownloadUrls(
            @RequestHeader(value = "Authorization", required = false) String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long userId = authExtractor.extractUserId(authorizationHeader);
        AlbumDownloadUrlsResponse resp = albumService.getAlbumDownloadUrls(userId, albumId);
        return ResponseEntity.ok(resp);
    }
}
