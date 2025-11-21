// backend/src/main/java/com/nemo/backend/domain/album/service/AlbumShareService.java
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

import java.util.*;

@Service
@RequiredArgsConstructor
@Transactional
public class AlbumShareService {

    private final AlbumRepository albumRepository;
    private final AlbumShareRepository albumShareRepository;
    private final FriendRepository friendRepository;
    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public Album getAlbum(Long albumId) {
        return albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));
    }

    private Album getAlbumWithManagePermission(Long albumId, Long meId) {
        Album album = getAlbum(albumId);

        if (album.getUser().getId().equals(meId)) {
            return album;
        }

        AlbumShare myShare = albumShareRepository
                .findByAlbumIdAndUserIdAndStatusAndActiveTrue(albumId, meId, Status.ACCEPTED)
                .orElseThrow(() -> new ApiException(ErrorCode.FORBIDDEN, "앨범 공유 관리 권한이 없습니다."));

        if (myShare.getRole() != Role.CO_OWNER) {
            throw new ApiException(ErrorCode.FORBIDDEN, "앨범 공유 관리 권한이 없습니다.");
        }

        return album;
    }

    // 공유 요청 보내기
    public AlbumShareResponse shareAlbum(Long albumId, Long meId, AlbumShareRequest req) {
        Album album = getAlbumWithManagePermission(albumId, meId);

        if (req.getFriendIdList() == null || req.getFriendIdList().isEmpty()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "friendIdList 가 비어 있습니다.");
        }

        Role defaultRole = Role.VIEWER;

        List<Long> friendIds = req.getFriendIdList().stream().distinct().toList();

        List<AlbumShare> toSave = new ArrayList<>();

        for (Long targetId : friendIds) {
            User target = userRepository.findById(targetId)
                    .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "존재하지 않는 사용자가 포함되어 있습니다."));

            boolean isFriend =
                    friendRepository.existsByUserIdAndFriendIdAndStatus(meId, targetId, FriendStatus.ACCEPTED) ||
                            friendRepository.existsByUserIdAndFriendIdAndStatus(targetId, meId, FriendStatus.ACCEPTED);

            if (!isFriend) {
                throw new ApiException(
                        ErrorCode.INVALID_REQUEST,
                        "친구 관계가 아닌 사용자에게는 앨범을 공유할 수 없습니다. userId=" + targetId
                );
            }

            Optional<AlbumShare> existingOpt =
                    albumShareRepository.findByAlbumIdAndUserId(albumId, targetId);

            if (existingOpt.isPresent()) {
                AlbumShare existing = existingOpt.get();

                if (Boolean.TRUE.equals(existing.getActive()) &&
                        (existing.getStatus() == Status.PENDING || existing.getStatus() == Status.ACCEPTED)) {
                    continue;
                }

                existing.setActive(true);
                existing.setStatus(Status.PENDING);
                existing.setRole(defaultRole);

                toSave.add(existing);
            } else {
                AlbumShare share = AlbumShare.builder()
                        .album(album)
                        .user(target)
                        .role(defaultRole)
                        .status(Status.PENDING)
                        .active(true)
                        .build();
                toSave.add(share);
            }
        }

        if (toSave.isEmpty()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "이미 모두 공유된 사용자입니다.");
        }

        albumShareRepository.saveAll(toSave);

        List<AlbumShareResponse.SharedTarget> sharedTo = toSave.stream()
                .map(share -> AlbumShareResponse.SharedTarget.builder()
                        .userId(share.getUser().getId())
                        .nickname(share.getUser().getNickname())
                        .build())
                .toList();

        return AlbumShareResponse.builder()
                .albumId(album.getId())
                .sharedTo(sharedTo)
                .message("앨범이 선택한 친구들에게 성공적으로 공유되었습니다.")
                .build();
    }

    @Transactional(readOnly = true)
    public List<AlbumShareResponse.SharedUser> getShareTargets(Long albumId, Long meId) {
        getAlbumWithManagePermission(albumId, meId);

        return albumShareRepository
                .findByAlbumIdAndActiveTrue(albumId).stream()
                .map(share -> AlbumShareResponse.SharedUser.builder()
                        .userId(share.getUser().getId())
                        .nickname(share.getUser().getNickname())
                        .role(share.getRole().name())
                        .build())
                .toList();
    }

    public AlbumShare updateShareRoleByUserId(Long albumId, Long targetUserId, Long meId, Role newRole) {
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
        return share;
    }

    public Long unshare(Long albumId, Long targetUserId, Long meId) {
        Album album = getAlbum(albumId);

        AlbumShare share = albumShareRepository
                .findByAlbumIdAndUserIdAndActiveTrue(albumId, targetUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "SHARE_NOT_FOUND"));

        if (targetUserId.equals(meId)) {
            if (!share.getUser().getId().equals(meId)) {
                throw new ApiException(ErrorCode.FORBIDDEN, "본인 공유가 아닙니다.");
            }
        } else {
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

        Long removedUserId = share.getUser().getId();
        share.setActive(false);
        share.setStatus(Status.REJECTED);

        return removedUserId;
    }

    @Transactional(readOnly = true)
    public List<PendingShareResponse> getPendingShares(Long meId) {
        return albumShareRepository
                .findByUserIdAndStatusAndActiveTrue(meId, Status.PENDING)
                .stream()
                .map(PendingShareResponse::from)
                .toList();
    }

    private void acceptShareInternal(AlbumShare share, Long meId) {
        if (!share.getUser().getId().equals(meId)) {
            throw new ApiException(ErrorCode.FORBIDDEN, "본인에게 온 공유만 수락할 수 있습니다.");
        }
        if (share.getStatus() != Status.PENDING || !Boolean.TRUE.equals(share.getActive())) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "이미 처리된 공유 요청입니다.");
        }

        share.setStatus(Status.ACCEPTED);
    }

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

    public AcceptShareResponse acceptShareByAlbum(Long albumId, Long meId) {
        AlbumShare share = albumShareRepository
                .findByAlbumIdAndUserIdAndStatusAndActiveTrue(albumId, meId, Status.PENDING)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "SHARE_NOT_FOUND"));

        acceptShareInternal(share, meId);

        return AcceptShareResponse.builder()
                .albumId(albumId)
                .role(share.getRole().name())
                .message("앨범 공유를 수락했습니다.")
                .build();
    }

    public RejectShareResponse rejectShareByAlbum(Long albumId, Long meId) {
        AlbumShare share = albumShareRepository
                .findByAlbumIdAndUserIdAndStatusAndActiveTrue(albumId, meId, Status.PENDING)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "SHARE_NOT_FOUND"));

        rejectShareInternal(share, meId);

        return RejectShareResponse.builder()
                .albumId(albumId)
                .message("앨범 공유 요청을 거절했습니다.")
                .build();
    }

    // 이 메서드는 내부용/추후용이라 HTTP 매핑은 제거했음
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

    public AlbumShareLinkResponse createShareLink(Long albumId, Long meId) {
        Album album = getAlbumWithManagePermission(albumId, meId);
        String url = "https://nemo.app/share/albums/" + album.getId();
        return new AlbumShareLinkResponse(album.getId(), url);
    }
}
