package com.nemo.backend.domain.album.service;

import com.nemo.backend.domain.album.dto.*;
import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.entity.AlbumShare;
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

@Service
@RequiredArgsConstructor
@Transactional
public class AlbumShareService {

    private final AlbumRepository albumRepository;
    private final UserRepository userRepository;
    private final FriendRepository friendRepository;
    private final AlbumShareRepository albumShareRepository;

    /** 앨범 소유자 or MANAGE 권한 체크 */
    private Album getAlbumWithManagePermission(Long albumId, Long meId) {
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        if (album.getUser().getId().equals(meId)) return album;

        albumShareRepository.findByAlbumIdAndUserIdAndActiveTrue(albumId, meId)
                .filter(s -> s.getRole() == AlbumShare.Role.MANAGE)
                .orElseThrow(() -> new ApiException(ErrorCode.FORBIDDEN, "FORBIDDEN"));

        return album;
    }

    /** POST /api/albums/{albumId}/share */
    public AlbumShareResponse shareAlbum(Long albumId, Long meId, AlbumShareRequest req) {
        Album album = getAlbumWithManagePermission(albumId, meId);

        if (req.friendIdList() == null || req.friendIdList().isEmpty()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "friendIdList is empty");
        }

        // 1) 친구 여부/중복 체크
        List<Long> targetIds = req.friendIdList().stream()
                .distinct()
                .filter(id -> !albumShareRepository.existsByAlbumIdAndUserIdAndActiveTrue(albumId, id))
                .toList();

        if (targetIds.isEmpty()) {
            throw new ApiException(ErrorCode.CONFLICT, "이미 모두 공유된 사용자입니다.");
        }

        // 친구 관계(ACCEPTED) 아닌 경우 에러
        for (Long targetId : targetIds) {
            boolean isFriend = friendRepository.existsByUserIdAndFriendIdAndStatus(
                    meId, targetId, FriendStatus.ACCEPTED
            );
            if (!isFriend) {
                throw new ApiException(ErrorCode.INVALID_REQUEST, "NOT_FRIEND");
            }
        }

        // 2) AlbumShare 생성
        List<AlbumShare> shares = targetIds.stream()
                .map(id -> AlbumShare.builder()
                        .album(album)
                        .user(userRepository.getReferenceById(id))
                        .role(AlbumShare.Role.VIEW) // 기본은 VIEW
                        .active(true)
                        .build())
                .toList();

        List<AlbumShare> saved = albumShareRepository.saveAll(shares);

        // 3) 응답 변환
        List<AlbumShareResponse.SharedUser> sharedTo = saved.stream()
                .map(s -> AlbumShareResponse.SharedUser.builder()
                        .userId(s.getUser().getId())
                        .nickname(s.getUser().getNickname())
                        .build())
                .toList();

        return AlbumShareResponse.builder()
                .albumId(albumId)
                .sharedTo(sharedTo)
                .message("앨범이 선택한 친구들에게 성공적으로 공유되었습니다.")
                .build();
    }

    /** GET /api/albums/{albumId}/share/targets */
    @Transactional(readOnly = true)
    public AlbumShareTargetsResponse getShareTargets(Long albumId, Long meId) {
        getAlbumWithManagePermission(albumId, meId);

        var list = albumShareRepository.findByAlbumIdAndActiveTrue(albumId).stream()
                .map(s -> AlbumShareResponse.SharedUser.builder()
                        .userId(s.getUser().getId())
                        .nickname(s.getUser().getNickname())
                        .build())
                .toList();

        return AlbumShareTargetsResponse.builder()
                .sharedTo(list)
                .build();
    }

    /** DELETE /api/albums/{albumId}/share/{userId} */
    public void unshare(Long albumId, Long meId, Long targetUserId) {
        // 소유자 or 자기 자신만 가능
        Album album = albumRepository.findById(albumId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "ALBUM_NOT_FOUND"));

        boolean isOwner = album.getUser().getId().equals(meId);

        AlbumShare share = albumShareRepository
                .findByAlbumIdAndUserIdAndActiveTrue(albumId, targetUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "SHARE_NOT_FOUND"));

        boolean isSelf = share.getUser().getId().equals(meId);

        if (!isOwner && !isSelf) {
            throw new ApiException(ErrorCode.FORBIDDEN, "FORBIDDEN");
        }

        share.setActive(false);
    }

    /** POST /api/albums/{albumId}/share/link */
    public AlbumShareLinkResponse createShareLink(Long albumId, Long meId) {
        // TODO: 실제로는 토큰/만료시간 기반 링크 만들어야 함. 지금은 더미 URL만.
        getAlbumWithManagePermission(albumId, meId);

        String url = "https://nemo.app/share/albums/" + albumId;
        return new AlbumShareLinkResponse(url);
    }
}
