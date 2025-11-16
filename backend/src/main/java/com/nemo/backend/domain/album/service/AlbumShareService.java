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
 * 앨범 공유 관련 비즈니스 로직
 */
@Service
@RequiredArgsConstructor
@Transactional
public class AlbumShareService {

    private final AlbumRepository albumRepository;
    private final AlbumShareRepository albumShareRepository;
    private final UserRepository userRepository;
    private final FriendRepository friendRepository;

    /**
     * OWNER 또는 CO_OWNER 만 접근 가능한 앨범 조회
     */
    private Album getAlbumWithManagePermission(Long albumId, Long meId) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        // OWNER
        if (album.getUser().getId().equals(meId)) {
            return album;
        }

        // CO_OWNER 권한이 있는지 확인
        AlbumShare share = albumShareRepository
                .findByAlbumIdAndUserIdAndStatusAndActiveTrue(albumId, meId, Status.ACCEPTED)
                .orElseThrow(() -> new ApiException(ErrorCode.FORBIDDEN, "앨범 공유 관리 권한이 없습니다."));

        if (share.getRole() != Role.CO_OWNER) {
            throw new ApiException(ErrorCode.FORBIDDEN, "앨범 공유 관리 권한이 없습니다.");
        }

        return album;
    }

    /**
     * 앨범 공유 요청 보내기
     */
    public AlbumShareResponse shareAlbum(Long albumId, Long meId, AlbumShareRequest req) {
        Album album = getAlbumWithManagePermission(albumId, meId);

        if (req.friendIdList() == null || req.friendIdList().isEmpty()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "friendIdList 가 비어 있습니다.");
        }

        Role defaultRole = (req.defaultRole() != null) ? req.defaultRole() : Role.VIEWER;

        // 중복 제거 + 이미 공유된 사용자 제외
        List<Long> targetIds = req.friendIdList().stream()
                .distinct()
                .filter(id -> !albumShareRepository.existsByAlbumIdAndUserIdAndActiveTrue(albumId, id))
                .toList();

        if (targetIds.isEmpty()) {
            throw new ApiException(ErrorCode.CONFLICT, "이미 모두 공유된 사용자입니다.");
        }

        // 친구 관계인지 확인 (ACCEPTED 상태만 허용)
        for (Long targetId : targetIds) {
            boolean isFriend = friendRepository.existsByUserIdAndFriendIdAndStatus(
                    meId, targetId, FriendStatus.ACCEPTED
            );
            if (!isFriend) {
                throw new ApiException(ErrorCode.INVALID_REQUEST, "친구가 아닌 사용자에게는 공유할 수 없습니다.");
            }
        }

        List<AlbumShare> shares = targetIds.stream()
                .map(id -> {
                    User target = userRepository.getReferenceById(id);
                    return AlbumShare.builder()
                            .album(album)
                            .user(target)
                            .role(defaultRole)
                            .status(Status.PENDING)
                            .active(true)
                            .build();
                })
                .toList();

        List<AlbumShare> saved = albumShareRepository.saveAll(shares);

        List<AlbumShareResponse.SharedUser> sharedTo = saved.stream()
                .map(s -> AlbumShareResponse.SharedUser.builder()
                        .shareId(s.getId())
                        .userId(s.getUser().getId())
                        .nickname(s.getUser().getNickname())
                        .email(s.getUser().getEmail())
                        .role(s.getRole())
                        .status(s.getStatus())
                        .invitedAt(s.getCreatedAt())
                        .build())
                .toList();

        return AlbumShareResponse.builder()
                .albumId(albumId)
                .sharedTo(sharedTo)
                .message("선택한 친구에게 앨범 공유 요청을 보냈습니다.")
                .build();
    }

    /**
     * 앨범에 공유된 사용자 목록 조회
     */
    @Transactional(readOnly = true)
    public AlbumShareTargetsResponse getShareTargets(Long albumId, Long meId) {
        getAlbumWithManagePermission(albumId, meId);

        List<AlbumShareResponse.SharedUser> list = albumShareRepository
                .findByAlbumIdAndActiveTrue(albumId).stream()
                .map(s -> AlbumShareResponse.SharedUser.builder()
                        .shareId(s.getId())
                        .userId(s.getUser().getId())
                        .nickname(s.getUser().getNickname())
                        .email(s.getUser().getEmail())
                        .role(s.getRole())
                        .status(s.getStatus())
                        .invitedAt(s.getCreatedAt())
                        .build())
                .toList();

        return AlbumShareTargetsResponse.builder()
                .albumId(albumId)
                .sharedTo(list)
                .build();
    }

    /**
     * 공유 대상의 권한(Role) 변경
     */
    public void updateShareRole(Long albumId, Long shareId, Long meId, Role newRole) {
        Album album = getAlbumWithManagePermission(albumId, meId);

        AlbumShare share = albumShareRepository.findById(shareId)
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
     * 공유 해제 (OWNER가 다른 사용자 강퇴, 혹은 본인이 나가기)
     */
    public void unshare(Long albumId, Long targetUserId, Long meId) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        AlbumShare share = albumShareRepository
                .findByAlbumIdAndUserIdAndActiveTrue(albumId, targetUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "SHARE_NOT_FOUND"));

        boolean isOwner = album.getUser().getId().equals(meId);
        boolean isSelf = share.getUser().getId().equals(meId);

        if (!isOwner && !isSelf) {
            throw new ApiException(ErrorCode.FORBIDDEN, "공유를 해제할 권한이 없습니다.");
        }

        share.setActive(false);
        share.setStatus(Status.REJECTED);
    }

    /**
     * 내가 "대기 중(PENDING)"인 공유 요청 목록
     */
    @Transactional(readOnly = true)
    public List<PendingShareResponse> getPendingShares(Long meId) {
        return albumShareRepository
                .findByUserIdAndStatusAndActiveTrue(meId, Status.PENDING)
                .stream()
                .map(PendingShareResponse::from)
                .toList();
    }

    /**
     * 공유 요청 수락
     */
    public void acceptShare(Long shareId, Long meId) {
        AlbumShare share = albumShareRepository.findById(shareId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "SHARE_NOT_FOUND"));

        if (!share.getUser().getId().equals(meId)) {
            throw new ApiException(ErrorCode.FORBIDDEN, "본인에게 온 공유만 수락할 수 있습니다.");
        }
        if (share.getStatus() != Status.PENDING || !Boolean.TRUE.equals(share.getActive())) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "이미 처리된 공유 요청입니다.");
        }

        share.setStatus(Status.ACCEPTED);
    }

    /**
     * 공유 요청 거절
     */
    public void rejectShare(Long shareId, Long meId) {
        AlbumShare share = albumShareRepository.findById(shareId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "SHARE_NOT_FOUND"));

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
     * 내가 공유받은 앨범 목록
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
     * 공유 링크 생성 (지금은 더미 URL, 실제 배포 시 토큰 기반으로 변경 필요)
     */
    public AlbumShareLinkResponse createShareLink(Long albumId, Long meId) {
        Album album = getAlbumWithManagePermission(albumId, meId);
        String url = "https://nemo.app/share/albums/" + album.getId(); // TODO: 실제 구현
        return new AlbumShareLinkResponse(album.getId(), url);
    }
}
