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

    // 🔹 공유 요청 보내기
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

    // 🔹 특정 앨범의 공유 대상 목록 조회
    @GetMapping("/{albumId}/share/targets")
    public ResponseEntity<AlbumShareTargetsResponse> getShareTargets(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        AlbumShareTargetsResponse resp = albumShareService.getShareTargets(albumId, meId);
        return ResponseEntity.ok(resp);
    }

    // 🔹 공유 대상 권한(Role) 변경
    @PutMapping("/{albumId}/share/{shareId}/role")
    public ResponseEntity<Void> updateShareRole(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId,
            @PathVariable Long shareId,
            @RequestParam("role") AlbumShare.Role role
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        albumShareService.updateShareRole(albumId, shareId, meId, role);
        return ResponseEntity.noContent().build();
    }

    // 🔹 공유 해제 (OWNER가 강퇴 or 본인이 나가기)
    @DeleteMapping("/{albumId}/share/{userId}")
    public ResponseEntity<Void> unshare(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long albumId,
            @PathVariable Long userId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        albumShareService.unshare(albumId, userId, meId);
        return ResponseEntity.noContent().build();
    }

    // 🔹 내가 "대기 중(PENDING)"인 공유 요청 목록
    @GetMapping("/shared/pending")
    public ResponseEntity<List<PendingShareResponse>> getPendingShares(
            @RequestHeader("Authorization") String authorizationHeader
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        List<PendingShareResponse> list = albumShareService.getPendingShares(meId);
        return ResponseEntity.ok(list);
    }

    // 🔹 공유 요청 수락
    @PostMapping("/shared/{shareId}/accept")
    public ResponseEntity<Void> acceptShare(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long shareId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        albumShareService.acceptShare(shareId, meId);
        return ResponseEntity.noContent().build();
    }

    // 🔹 공유 요청 거절
    @PostMapping("/shared/{shareId}/reject")
    public ResponseEntity<Void> rejectShare(
            @RequestHeader("Authorization") String authorizationHeader,
            @PathVariable Long shareId
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        albumShareService.rejectShare(shareId, meId);
        return ResponseEntity.noContent().build();
    }

    // 🔹 내가 공유받은 앨범 목록
    @GetMapping("/shared/me")
    public ResponseEntity<List<SharedAlbumSummaryResponse>> getMySharedAlbums(
            @RequestHeader("Authorization") String authorizationHeader
    ) {
        Long meId = authExtractor.extractUserId(authorizationHeader);
        List<SharedAlbumSummaryResponse> list = albumShareService.getMySharedAlbums(meId);
        return ResponseEntity.ok(list);
    }

    // 🔹 공유 링크 생성
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
