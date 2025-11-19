package com.nemo.backend.domain.friend.service;

import com.nemo.backend.domain.friend.dto.*;
import com.nemo.backend.domain.friend.entity.Friend;
import com.nemo.backend.domain.friend.entity.FriendStatus;
import com.nemo.backend.domain.friend.repository.FriendRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * FriendService
 * -------------------------
 * 친구 관련 핵심 비즈니스 로직을 담당하는 클래스.
 * 컨트롤러에서 요청을 받으면 실제 처리(검증, 저장, 조회 등)를 수행.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class FriendService {

    private final FriendRepository friendRepository;
    private final UserRepository userRepository;

    // ====================================================================
    // 1. 친구 요청 보내기
    // ====================================================================

    /**
     * ✅ 친구 요청 보내기
     * --------------------------------
     * - A(meId) 사용자가 B(targetUserId)에게 친구 요청을 보낼 때 호출
     * - 중복 요청, 자기 자신 요청 등을 방지
     * - 상태(status)는 기본적으로 PENDING
     * - 컨트롤러에 맞게 FriendAddResponse DTO 반환
     */
    public FriendAddResponse sendFriendRequest(Long meId, Long targetUserId) {
        // 1) 자기 자신에게 요청하는 경우 차단
        if (meId.equals(targetUserId)) {
            throw new IllegalArgumentException("자기 자신은 친구로 추가할 수 없습니다.");
        }

        // 2) 이미 나 → 상대, 상대 → 나 관계가 있는지 체크
        boolean existsForward = friendRepository.existsByUserIdAndFriendId(meId, targetUserId);
        boolean existsBackward = friendRepository.existsByUserIdAndFriendId(targetUserId, meId);
        if (existsForward || existsBackward) {
            throw new IllegalStateException("이미 친구 요청을 보냈거나 친구 상태입니다.");
        }

        // 3) 요청자와 대상 사용자 조회 (없으면 예외 발생)
        User me = userRepository.findById(meId)
                .orElseThrow(() -> new IllegalArgumentException("내 계정이 존재하지 않습니다."));
        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new IllegalArgumentException("대상 사용자가 존재하지 않습니다."));

        // 4) 친구 요청 저장 (status = PENDING)
        Friend saved = friendRepository.save(Friend.createRequest(me, target));

        // 5) 명세서에 맞게 응답 DTO 구성
        return FriendAddResponse.builder()
                .requestId(saved.getId())
                .status(saved.getStatus().name()) // 보통 "PENDING"
                .message("친구 요청이 전송되었습니다.")
                .target(FriendAddResponse.TargetUser.builder()
                        .userId(target.getId())
                        .nickname(target.getNickname())
                        .profileImageUrl(target.getProfileImageUrl())
                        .build())
                .build();
    }

    // ====================================================================
    // 2. 친구 목록 조회
    // ====================================================================

    /**
     * ✅ 친구 목록 조회
     * --------------------------------
     * - 내가 수락한 친구 목록을 불러옴 (status = ACCEPTED)
     * - 반환 값은 FriendListResponse DTO 리스트 (친구들의 정보)
     */
    @Transactional(readOnly = true)
    public List<FriendListResponse> getFriendList(Long meId) {
        return friendRepository.findAllByUserIdAndStatus(meId, FriendStatus.ACCEPTED)
                .stream()
                .map(Friend::getFriend) // Friend 엔티티에서 friend(User) 객체만 꺼냄
                .map(u -> FriendListResponse.builder()
                        .userId(u.getId())
                        .email(u.getEmail())
                        .nickname(u.getNickname())
                        .profileImageUrl(u.getProfileImageUrl())
                        .build())
                .toList();
    }

    // ====================================================================
    // 3. 친구 삭제
    // ====================================================================

    /**
     * ✅ 친구 삭제 (양방향)
     * --------------------------------
     * - 나(meId)가 특정 친구(friendId)를 삭제할 때 사용
     * - me → friend, friend → me 두 방향의 친구 관계를 모두 제거
     */
    public FriendDeleteResponse deleteFriend(Long meId, Long friendId) {
        // 1) me -> friend 관계 삭제
        friendRepository.findByUserIdAndFriendId(meId, friendId)
                .ifPresent(friendRepository::delete);

        // 2) friend -> me 관계도 함께 삭제
        friendRepository.findByUserIdAndFriendId(friendId, meId)
                .ifPresent(friendRepository::delete);

        return FriendDeleteResponse.builder()
                .message("친구 관계가 해제되었습니다.")
                .deletedFriendId(friendId)
                .build();
    }

    // ====================================================================
    // 4. 친구 검색
    // ====================================================================

    /**
     * ✅ 친구 검색
     * --------------------------------
     * - 닉네임 또는 이메일 일부로 사용자 검색
     * - 자기 자신 제외
     * - 이미 친구인 경우 isFriend = true 반환
     */
    @Transactional(readOnly = true)
    public List<FriendSearchResponse> searchFriends(Long meId, String keyword) {
        // UserRepository 쪽에서 닉네임/이메일 LIKE 검색
        List<User> candidates = userRepository.searchByNicknameOrEmail(keyword);

        return candidates.stream()
                .filter(u -> !u.getId().equals(meId)) // 자기 자신 제외
                .map(u -> FriendSearchResponse.builder()
                        .userId(u.getId())
                        .nickname(u.getNickname())
                        .email(u.getEmail())
                        .profileImageUrl(u.getProfileImageUrl())
                        // 나(meId)와 이미 친구인지 여부 체크 (true/false)
                        .isFriend(friendRepository.existsByUserIdAndFriendId(meId, u.getId()))
                        .build()
                )
                .toList();
    }

    // ====================================================================
    // 5. 나에게 온 친구 요청 목록 조회 (PENDING)
    // ====================================================================

    /**
     * ✅ 친구 요청 목록 조회 (나에게 도착한 요청들)
     * --------------------------------
     * - "나(meId)를 friend로 가진" Friend 엔티티들 중
     *   상태가 PENDING 인 것만 조회
     * - 명세서의 "친구 요청 목록 조회 API"에 대응
     *
     * 필요한 Repository 메서드:
     *  List<Friend> findAllByFriendIdAndStatus(Long friendId, FriendStatus status);
     */
    @Transactional(readOnly = true)
    public List<FriendRequestSummaryResponse> getIncomingRequests(Long meId) {
        // 1) 나에게 온 PENDING 상태의 친구 요청 목록 조회
        List<Friend> requests = friendRepository.findAllByFriendIdAndStatus(meId, FriendStatus.PENDING);

        // 2) API 응답용 DTO로 변환
        return requests.stream()
                .map(request -> {
                    User requester = request.getUser(); // 요청 보낸 사람(A)
                    return FriendRequestSummaryResponse.builder()
                            .requestId(request.getId())                          // Friend 엔티티 PK
                            .userId(requester.getId())                           // 요청 보낸 사람 ID
                            .nickname(requester.getNickname())                   // 요청 보낸 사람 닉네임
                            .email(requester.getEmail())                         // 요청 보낸 사람 이메일
                            .profileImageUrl(requester.getProfileImageUrl())     // 요청 보낸 사람 프로필 이미지
                            // createdAt이 BaseTimeEntity 등에 있다면 toString()으로 ISO 형태 사용
                            .requestedAt(request.getCreatedAt() != null
                                    ? request.getCreatedAt().toString()
                                    : null)
                            .build();
                })
                .toList();
    }

    // ====================================================================
    // 6. 친구 요청 수락 (requestId 기준)
    // ====================================================================

    /**
     * ✅ 친구 요청 수락
     * --------------------------------
     * - 나(meId)에게 도착한 친구 요청(requestId)을 수락
     * - 권한 체크: 해당 요청의 대상(friend)이 나(meId)인지 확인
     * - 상태를 PENDING → ACCEPTED로 변경하고,
     *   양방향 친구 관계를 완성시킴.
     */
    public FriendRequestAcceptResponse acceptFriendRequest(Long meId, Long requestId) {
        // 1) 요청 엔티티 조회
        Friend request = friendRepository.findById(requestId)
                .orElseThrow(() -> new IllegalArgumentException("해당 친구 요청이 존재하지 않습니다."));

        // 2) 권한 체크: 이 요청의 대상이 내가 맞는지 확인
        User me = request.getFriend();      // 요청의 대상 사용자
        User requester = request.getUser(); // 요청 보낸 사용자

        if (!me.getId().equals(meId)) {
            throw new IllegalStateException("해당 친구 요청을 수락할 권한이 없습니다.");
        }

        // 3) 상태 변경: PENDING → ACCEPTED
        request.accept();

        // 4) 반대 방향(B→A) 관계 생성 (양방향 친구 완성)
        friendRepository.save(
                Friend.builder()
                        .user(me)
                        .friend(requester)
                        .status(FriendStatus.ACCEPTED)
                        .build()
        );

        // 5) 응답 DTO 구성
        return FriendRequestAcceptResponse.builder()
                .requestId(request.getId())
                .friendUserId(requester.getId())
                .nickname(requester.getNickname())
                .message("친구 요청이 성공적으로 수락되었습니다.")
                .build();
    }

    // ====================================================================
    // 7. 친구 요청 거절 (requestId 기준)
    // ====================================================================

    /**
     * ✅ 친구 요청 거절
     * --------------------------------
     * - 나(meId)에게 도착한 친구 요청(requestId)을 거절
     * - 현재 정책: 요청 row 자체를 삭제
     *   (만약 REJECTED 상태를 유지하고 싶다면 enum/메서드 추가 필요)
     */
    public FriendRequestRejectResponse rejectFriendRequest(Long meId, Long requestId) {
        // 1) 요청 엔티티 조회
        Friend request = friendRepository.findById(requestId)
                .orElseThrow(() -> new IllegalArgumentException("해당 친구 요청이 존재하지 않습니다."));

        // 2) 권한 체크: 이 요청의 대상이 내가 맞는지 확인
        User target = request.getFriend();
        if (!target.getId().equals(meId)) {
            throw new IllegalStateException("해당 친구 요청을 거절할 권한이 없습니다.");
        }

        // 3) 현재 정책: 요청 row 자체 삭제
        friendRepository.delete(request);

        // 4) 응답 DTO
        return FriendRequestRejectResponse.builder()
                .requestId(requestId)
                .message("친구 요청이 거절되었습니다.")
                .build();
    }
}
