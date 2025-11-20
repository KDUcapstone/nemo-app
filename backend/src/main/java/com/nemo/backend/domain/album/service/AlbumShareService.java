package com.nemo.backend.domain.album.service;

import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.entity.AlbumShare;
import com.nemo.backend.domain.album.entity.AlbumShare.Role;
import com.nemo.backend.domain.album.entity.AlbumShare.Status;
import com.nemo.backend.domain.album.repository.AlbumRepository;
import com.nemo.backend.domain.album.repository.AlbumShareRepository;
import com.nemo.backend.domain.friend.entity.FriendStatus;
import com.nemo.backend.domain.friend.repository.FriendRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 앨범 공유(초대/수락/거절/권한 변경) 비즈니스 로직
 * - HTTP 엔드포인트는 AlbumShareController 에서 처리
 * - "신 명세" 기준으로만 작성됨
 */
@Service
@RequiredArgsConstructor
@Transactional
public class AlbumShareService {

    private final AlbumRepository albumRepository;
    private final AlbumShareRepository albumShareRepository;
    private final FriendRepository friendRepository;
    private final UserRepository userRepository;

    /** 앨범 단건 조회 (없으면 404) */
    @Transactional(readOnly = true)
    public Album getAlbum(Long albumId) {
        return albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));
    }

    /** OWNER 또는 CO_OWNER 권한 확인용 헬퍼 */
    private Album getAlbumWithManagePermission(Long albumId, Long meId) {
        Album album = getAlbum(albumId);

        // OWNER 이면 바로 통과
        if (album.getUser().getId().equals(meId)) {
            return album;
        }

        // CO_OWNER 권한이 있는지 검사
        AlbumShare myShare = albumShareRepository
                .findByAlbumIdAndUserIdAndStatusAndActiveTrue(albumId, meId, Status.ACCEPTED)
                .orElseThrow(() -> new ApiException(ErrorCode.FORBIDDEN, "앨범 공유 관리 권한이 없습니다."));

        if (myShare.getRole() != Role.CO_OWNER) {
            throw new ApiException(ErrorCode.FORBIDDEN, "앨범 공유 관리 권한이 없습니다.");
        }

        return album;
    }

    /**
     * ✅ 앨범 공유 요청 보내기
     * - POST /api/albums/{albumId}/share
     */
    public AlbumShareResponse shareAlbum(Long albumId, Long meId, AlbumShareRequest req) {
        Album album = getAlbumWithManagePermission(albumId, meId);

        if (req.friendIdList() == null || req.friendIdList().isEmpty()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "friendIdList 가 비어 있습니다.");
        }

        Role defaultRole = (req.defaultRole() != null) ? req.defaultRole() : Role.VIEWER;

        // 중복 제거 + 이미 공유된 사용자 제거
        List<Long> targetIds = req.friendIdList().stream()
                .distinct()
                .filter(id -> !albumShareRepository.existsByAlbumIdAndUserIdAndActiveTrue(albumId, id))
                .toList();

        if (targetIds.isEmpty()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "이미 모두 공유된 사용자입니다.");
        }

        // 대상 사용자 조회 및 존재 여부 확인
        List<User> targets = userRepository.findAllById(targetIds);
        if (targets.size() != targetIds.size()) {
            throw new ApiException(ErrorCode.NOT_FOUND, "존재하지 않는 사용자가 포함되어 있습니다.");
        }

        // 친구 상태(ACCEPTED)인지 확인 (양방향 모두 검사)
        for (User target : targets) {
            Long targetId = target.getId();
            boolean isFriend =
                    friendRepository.existsByUserIdAndFriendIdAndStatus(meId, targetId, FriendStatus.ACCEPTED) ||
                            friendRepository.existsByUserIdAndFriendIdAndStatus(targetId, meId, FriendStatus.ACCEPTED);

            if (!isFriend) {
                throw new ApiException(
                        ErrorCode.INVALID_REQUEST,
                        "친구 관계가 아닌 사용자에게는 앨범을 공유할 수 없습니다. userId=" + targetId
                );
            }
        }

        // AlbumShare row 생성
        List<AlbumShare> shares = targets.stream()
                .map(target -> AlbumShare.builder()
                        .album(album)
                        .user(target)
                        .role(defaultRole)
                        .status(Status.PENDING)
                        .active(true)
                        .build())
                .toList();

        albumShareRepository.saveAll(shares);

        // 응답 DTO 구성
        List<AlbumShareResponse.SharedUser> sharedUsers = shares.stream()
                .map(share -> AlbumShareResponse.SharedUser.builder()
                        .shareId(share.getId())
                        .userId(share.getUser().getId())
                        .nickname(share.getUser().getNickname())
                        .email(share.getUser().getEmail())
                        .role(share.getRole())
                        .status(share.getStatus())
                        .invitedAt(share.getCreatedAt())
                        .build())
                .toList();

        return AlbumShareResponse.builder()
                .albumId(album.getId())
                .sharedTo(sharedUsers)
                .message(null) // 현재 명세에는 별도 메시지 필드 없음
                .build();
    }

    /**
     * ✅ 공유 멤버 목록 조회
     * - GET /api/albums/{albumId}/share/members
     */
    @Transactional(readOnly = true)
    public AlbumShareTargetsResponse getShareTargets(Long albumId, Long meId) {
        // OWNER / CO_OWNER 권한 검증
        getAlbumWithManagePermission(albumId, meId);

        List<AlbumShareResponse.SharedUser> list = albumShareRepository
                .findByAlbumIdAndActiveTrue(albumId).stream()
                .map(share -> AlbumShareResponse.SharedUser.builder()
                        .shareId(share.getId())
                        .userId(share.getUser().getId())
                        .nickname(share.getUser().getNickname())
                        .email(share.getUser().getEmail())
                        .role(share.getRole())
                        .status(share.getStatus())
                        .invitedAt(share.getCreatedAt())
                        .build())
                .toList();

        return AlbumShareTargetsResponse.builder()
                .albumId(albumId)
                .sharedTo(list)
                .build();
    }

    /**
     * ✅ 공유 멤버 권한 변경 (targetUserId 기준)
     * - PUT /api/albums/{albumId}/share/permission
     */
    public void updateShareRoleByUserId(Long albumId, Long targetUserId, Long meId, Role newRole) {
        Album album = getAlbumWithManagePermission(albumId, meId);

        AlbumShare share = albumShareRepository
                .findByAlbumIdAndUserIdAndActiveTrue(albumId, targetUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "SHARE_NOT_FOUND"));

        if (!share.getAlbum().getId().equals(album.getId())) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "앨범 정보가 일치하지 않습니다.");
        }
        if (!Boolean.TRUE.equals(share.getActive()) || share.getStatus() != Status.ACCEPTED) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "활성화된 공유가 아닙니다.");
        }

        share.setRole(newRole);
    }

    /**
     * ✅ 공유 해제 (OWNER/CO_OWNER가 강퇴 or 본인이 나가기)
     * - DELETE /api/albums/{albumId}/share/{targetUserId}
     */
    public void unshare(Long albumId, Long targetUserId, Long meId) {
        Album album = getAlbum(albumId);

        AlbumShare share = albumShareRepository
                .findByAlbumIdAndUserIdAndActiveTrue(albumId, targetUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "SHARE_NOT_FOUND"));

        // 본인이 나가는 경우
        if (targetUserId.equals(meId)) {
            if (!share.getUser().getId().equals(meId)) {
                throw new ApiException(ErrorCode.FORBIDDEN, "본인 공유가 아닙니다.");
            }
        } else {
            // OWNER 또는 CO_OWNER 만 강퇴 가능
            if (!album.getUser().getId().equals(meId)) {
                AlbumShare myShare = albumShareRepository
                        .findByAlbumIdAndUserIdAndStatusAndActiveTrue(albumId, meId, Status.ACCEPTED)
                        .orElseThrow(() -> new ApiException(ErrorCode.FORBIDDEN, "앨범 공유 관리 권한이 없습니다."));
                if (myShare.getRole() != Role.CO_OWNER) {
                    throw new ApiException(ErrorCode.FORBIDDEN, "앨범 공유 관리 권한이 없습니다.");
                }
            }
        }

        if (!Boolean.TRUE.equals(share.getActive())) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "이미 비활성화된 공유입니다.");
        }

        share.setActive(false);
        share.setStatus(Status.REJECTED);
    }

    /**
     * ✅ 내가 받은 공유 요청 목록 (PENDING)
     * - GET /api/albums/share/requests
     */
    @Transactional(readOnly = true)
    public List<PendingShareResponse> getPendingShares(Long meId) {
        return albumShareRepository
                .findByUserIdAndStatusAndActiveTrue(meId, Status.PENDING)
                .stream()
                .map(PendingShareResponse::from)
                .toList();
    }

    /** 내부 공통: 공유 수락 처리 */
    private void acceptShareInternal(AlbumShare share, Long meId) {
        if (!share.getUser().getId().equals(meId)) {
            throw new ApiException(ErrorCode.FORBIDDEN, "본인에게 온 공유만 수락할 수 있습니다.");
        }
        if (share.getStatus() != Status.PENDING || !Boolean.TRUE.equals(share.getActive())) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "이미 처리된 공유 요청입니다.");
        }

        share.setStatus(Status.ACCEPTED);
    }

    /** 내부 공통: 공유 거절 처리 */
    private void rejectShareInternal(AlbumShare share, Long meId) {
        if (!share.getUser().getId().equals(meId)) {
            throw new ApiException(ErrorCode.FORBIDDEN, "본인에게 온 공유만 거절할 수 있습니다.");
        }
        if (share.getStatus() != Status.PENDING || !Boolean.TRUE.equals(share.getActive())) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "이미 처리된 공유 요청입니다.");
        }

        share.setStatus(Status.REJECTED);
        share.setActive(false);
    }

    /**
     * ✅ 공유 요청 수락 (albumId 기준)
     * - POST /api/albums/{albumId}/share/accept
     */
    public void acceptShareByAlbum(Long albumId, Long meId) {
        AlbumShare share = albumShareRepository
                .findByAlbumIdAndUserIdAndStatusAndActiveTrue(albumId, meId, Status.PENDING)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "SHARE_NOT_FOUND"));

        acceptShareInternal(share, meId);
    }

    /**
     * ✅ 공유 요청 거절 (albumId 기준)
     * - POST /api/albums/{albumId}/share/reject
     */
    public void rejectShareByAlbum(Long albumId, Long meId) {
        AlbumShare share = albumShareRepository
                .findByAlbumIdAndUserIdAndStatusAndActiveTrue(albumId, meId, Status.PENDING)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "SHARE_NOT_FOUND"));

        rejectShareInternal(share, meId);
    }

    /**
     * ✅ 내가 공유받은 앨범 목록
     * - 실제 HTTP 엔드포인트는 AlbumController 에서 통합 처리 가능
     */
    @Transactional(readOnly = true)
    public List<SharedAlbumSummaryResponse> getMySharedAlbums(Long meId) {
        List<AlbumShare> shares = albumShareRepository
                .findByUserIdAndStatusAndActiveTrue(meId, Status.ACCEPTED);

        return shares.stream()
                .map(share -> {
                    Album album = share.getAlbum();
                    int photoCount = (album.getPhotos() == null) ? 0 : album.getPhotos().size();
                    String coverUrl = album.getCoverPhotoUrl();
                    return SharedAlbumSummaryResponse.from(album, share, coverUrl, photoCount);
                })
                .toList();
    }

    /**
     * ✅ 공유 링크 생성 (임시 구현)
     * - POST /api/albums/{albumId}/share/link
     */
    public AlbumShareLinkResponse createShareLink(Long albumId, Long meId) {
        Album album = getAlbumWithManagePermission(albumId, meId);
        String url = "https://nemo.app/share/albums/" + album.getId(); // TODO: 토큰 기반 링크로 교체
        return new AlbumShareLinkResponse(album.getId(), url);
    }
}
