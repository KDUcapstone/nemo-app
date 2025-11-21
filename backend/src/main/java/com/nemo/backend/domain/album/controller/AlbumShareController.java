// backend/src/main/java/com/nemo/backend/domain/album/controller/AlbumShareController.java
package com.nemo.backend.domain.album.controller;

import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.entity.AlbumShare;
import com.nemo.backend.domain.album.service.AlbumShareService;
import com.nemo.backend.domain.auth.util.AuthExtractor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping(
        value = "/api/albums",
        produces = "application/json; charset=UTF-8"
)
public class AlbumShareController {

    private final AlbumShareService albumShareService;
    private final AuthExtractor authExtractor;

    // 1) POST /api/albums/{albumId}/share : 앨범 공유 요청
    @PostMapping("/{albumId}/share")
    public ResponseEntity<AlbumShareResponse> shareAlbum(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId,
            @RequestBody AlbumShareRequest request
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        AlbumShareResponse resp = albumShareService.shareAlbum(albumId, meId, request);
        return ResponseEntity.ok(resp);
    }

    // 2) GET /api/albums/{albumId}/share/members : 공유 멤버 목록
    @GetMapping("/{albumId}/share/members")
    public ResponseEntity<List<AlbumShareResponse.SharedUser>> getShareMembers(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        List<AlbumShareResponse.SharedUser> resp = albumShareService.getShareTargets(albumId, meId);
        return ResponseEntity.ok(resp);
    }

    // 3) PUT /api/albums/{albumId}/share/permission : 공유 멤버 권한 변경
    @PutMapping("/{albumId}/share/permission")
    public ResponseEntity<UpdateSharePermissionResponse> updateSharePermission(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId,
            @RequestBody UpdateSharePermissionRequest request
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);

        AlbumShare updated = albumShareService.updateShareRoleByUserId(
                albumId,
                request.getTargetUserId(),
                meId,
                request.getRole()
        );

        UpdateSharePermissionResponse resp = UpdateSharePermissionResponse.builder()
                .albumId(albumId)
                .targetUserId(updated.getUser().getId())
                .role(updated.getRole().name())
                .message("공유 멤버 권한이 변경되었습니다.")
                .build();

        return ResponseEntity.ok(resp);
    }

    // 4) DELETE /api/albums/{albumId}/share/{targetUserId} : 공유 해제
    @DeleteMapping("/{albumId}/share/{targetUserId}")
    public ResponseEntity<UnshareResponse> unshare(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId,
            @PathVariable("targetUserId") Long targetUserId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        Long removedUserId = albumShareService.unshare(albumId, targetUserId, meId);

        UnshareResponse resp = UnshareResponse.builder()
                .albumId(albumId)
                .removedUserId(removedUserId)
                .message("해당 사용자를 앨범에서 제거했습니다.")
                .build();

        return ResponseEntity.ok(resp);
    }

    // 5) GET /api/albums/share/requests : 내가 받은 공유 요청 목록
    @GetMapping("/share/requests")
    public ResponseEntity<List<PendingShareResponse>> getShareRequests(
            @RequestHeader("Authorization") String authorizationHeader
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        List<PendingShareResponse> list = albumShareService.getPendingShares(meId);
        return ResponseEntity.ok(list);
    }

    // 6) POST /api/albums/{albumId}/share/accept : 공유 요청 수락
    @PostMapping("/{albumId}/share/accept")
    public ResponseEntity<AcceptShareResponse> acceptShareByAlbum(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        AcceptShareResponse resp = albumShareService.acceptShareByAlbum(albumId, meId);
        return ResponseEntity.ok(resp);
    }

    // 7) POST /api/albums/{albumId}/share/reject : 공유 요청 거절
    @PostMapping("/{albumId}/share/reject")
    public ResponseEntity<RejectShareResponse> rejectShareByAlbum(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        RejectShareResponse resp = albumShareService.rejectShareByAlbum(albumId, meId);
        return ResponseEntity.ok(resp);
    }

    // 8) POST /api/albums/{albumId}/share/link : 공유 링크 생성
    @PostMapping("/{albumId}/share/link")
    public ResponseEntity<AlbumShareLinkResponse> createShareLink(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        AlbumShareLinkResponse resp = albumShareService.createShareLink(albumId, meId);
        return ResponseEntity.ok(resp);
    }

    // 🔥 /api/albums/shared 제거 (명세에 없음, ownership=SHARED 로 대체)
}
