package com.nemo.backend.domain.album.controller;

import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.entity.AlbumShare;
import com.nemo.backend.domain.album.service.AlbumShareService;
import com.nemo.backend.domain.auth.util.AuthExtractor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 앨범 공유 관련 API 전용 컨트롤러
 * base-url: /api/albums
 */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/albums")
public class AlbumShareController {

    private final AlbumShareService albumShareService;
    private final AuthExtractor authExtractor;

    // 🔹 앨범 공유 요청 보내기
    // POST /api/albums/{albumId}/share
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

    // 🔹 공유 멤버 목록 조회 (신 명세)
    // GET /api/albums/{albumId}/share/members
    @GetMapping("/{albumId}/share/members")
    public ResponseEntity<AlbumShareTargetsResponse> getShareMembers(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        AlbumShareTargetsResponse resp = albumShareService.getShareTargets(albumId, meId);
        return ResponseEntity.ok(resp);
    }

    // 🔹 공유 멤버 권한 변경 (신 명세: targetUserId 기반)
    // PUT /api/albums/{albumId}/share/permission
    @PutMapping("/{albumId}/share/permission")
    public ResponseEntity<Void> updateSharePermission(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId,
            @RequestBody UpdateSharePermissionRequest request
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        albumShareService.updateShareRoleByUserId(
                albumId,
                request.targetUserId(),
                meId,
                request.role()
        );
        // 명세서는 200 OK 예시라 OK로 응답
        return ResponseEntity.ok().build();
    }

    // 🔹 공유 해제 (OWNER가 강퇴 or 본인이 나가기)
    // DELETE /api/albums/{albumId}/share/{targetUserId}
    @DeleteMapping("/{albumId}/share/{targetUserId}")
    public ResponseEntity<Void> unshare(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId,
            @PathVariable("targetUserId") Long targetUserId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        albumShareService.unshare(albumId, targetUserId, meId);
        return ResponseEntity.noContent().build();
    }

    // 🔹 공유 요청 목록 조회 (신 명세)
    // GET /api/albums/share/requests
    @GetMapping("/share/requests")
    public ResponseEntity<List<PendingShareResponse>> getShareRequests(
            @RequestHeader("Authorization") String authorizationHeader
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        List<PendingShareResponse> list = albumShareService.getPendingShares(meId);
        return ResponseEntity.ok(list);
    }

    // 🔹 공유 요청 수락 (신 명세: albumId 기반)
    // POST /api/albums/{albumId}/share/accept
    @PostMapping("/{albumId}/share/accept")
    public ResponseEntity<Void> acceptShareByAlbum(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        albumShareService.acceptShareByAlbum(albumId, meId);
        // 명세 예시는 200 OK
        return ResponseEntity.ok().build();
    }

    // 🔹 공유 요청 거절 (신 명세: albumId 기반)
    // POST /api/albums/{albumId}/share/reject
    @PostMapping("/{albumId}/share/reject")
    public ResponseEntity<Void> rejectShareByAlbum(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        albumShareService.rejectShareByAlbum(albumId, meId);
        return ResponseEntity.ok().build();
    }

    // 🔹 공유 링크 생성 (명세 참고용 / 실제 배포 시 토큰 기반 링크로 개선 필요)
    // POST /api/albums/{albumId}/share/link
    @PostMapping("/{albumId}/share/link")
    public ResponseEntity<AlbumShareLinkResponse> createShareLink(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        AlbumShareLinkResponse resp = albumShareService.createShareLink(albumId, meId);
        return ResponseEntity.ok(resp);
    }
}