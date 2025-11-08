package com.nemo.backend.domain.friend.service;

import com.nemo.backend.domain.friend.dto.FriendListResponse;
import com.nemo.backend.domain.friend.dto.FriendSearchResponse;
import com.nemo.backend.domain.friend.entity.Friend;
import com.nemo.backend.domain.friend.entity.FriendStatus;
import com.nemo.backend.domain.friend.repository.FriendRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

/**
 * FriendService
 * -------------------------
 * 친구 관련 핵심 비즈니스 로직을 담당하는 클래스.
 * 컨트롤러에서 요청을 받으면 실제 처리(검증, 저장, 조회 등)를 수행.
 */
@Service
@RequiredArgsConstructor // 생성자 주입 자동
@Transactional // 기본적으로 모든 메서드가 트랜잭션 안에서 실행됨
public class FriendService {

    private final FriendRepository friendRepository;
    private final UserRepository userRepository;

    /**
     * ✅ 친구 요청 보내기
     * --------------------------------
     * - A 사용자가 B에게 친구 요청을 보낼 때 호출됨
     * - 중복 요청, 자기 자신 요청 등을 방지
     * - 상태(status)는 기본적으로 PENDING
     */
    public void sendFriendRequest(Long meId, Long targetId) {
        // 자기 자신에게 요청하는 경우 차단
        if (meId.equals(targetId)) {
            throw new IllegalArgumentException("자기 자신은 친구로 추가할 수 없습니다.");
        }

        // 이미 친구 요청을 보냈거나 친구 상태라면 차단
        if (friendRepository.existsByUserIdAndFriendId(meId, targetId)) {
            throw new IllegalStateException("이미 친구 요청을 보냈거나 친구 상태입니다.");
        }

        // 요청자와 대상 사용자 조회 (없으면 예외 발생)
        User me = userRepository.findById(meId)
                .orElseThrow(() -> new IllegalArgumentException("내 계정이 존재하지 않습니다."));
        User target = userRepository.findById(targetId)
                .orElseThrow(() -> new IllegalArgumentException("대상 사용자가 존재하지 않습니다."));

        // 친구 요청 저장 (status = PENDING)
        friendRepository.save(Friend.createRequest(me, target));
    }

    /**
     * ✅ 친구 목록 조회
     * --------------------------------
     * - 내가 수락한 친구 목록을 불러옴 (status = ACCEPTED)
     * - 반환 값은 User 엔티티 리스트 (친구들의 정보)
     */
    @Transactional(readOnly = true)
    public List<FriendListResponse> getFriendList(Long meId) {
        return friendRepository.findAllByUserIdAndStatus(meId, FriendStatus.ACCEPTED)
                .stream()
                .map(Friend::getFriend) // User
                .map(u -> FriendListResponse.builder()
                        .userId(u.getId())
                        .email(u.getEmail())
                        .nickname(u.getNickname())
                        .profileImageUrl(u.getProfileImageUrl())
                        .build())
                .toList();
    }

    /**
     * ✅ 친구 요청 수락
     * --------------------------------
     * - B 사용자가 A의 친구 요청을 수락할 때 호출
     * - 기존 A→B 요청의 상태를 ACCEPTED로 변경
     * - 동시에 B→A 반대 방향으로도 관계 추가 (양방향 친구 완성)
     */
    public void acceptFriend(Long userId, Long requesterId) {
        // 1️⃣ 기존 요청(A→B) 찾기
        Friend request = friendRepository.findByUserIdAndFriendId(requesterId, userId)
                .orElseThrow(() -> new IllegalArgumentException("친구 요청이 존재하지 않습니다."));

        // 2️⃣ 요청 상태 변경: PENDING → ACCEPTED
        request.accept();

        // 3️⃣ 반대 방향(B→A) 관계 생성 (양방향 친구 완성)
        User user = userRepository.findById(userId).orElseThrow();
        User requester = userRepository.findById(requesterId).orElseThrow();
        friendRepository.save(
                Friend.builder()
                        .user(user)
                        .friend(requester)
                        .status(FriendStatus.ACCEPTED)
                        .build()
        );
    }

    /**
     * ✅ 친구 삭제
     * --------------------------------
     * - 나(me)가 특정 친구(friendId)를 삭제할 때 사용
     * - DB에서 친구 관계 한쪽 방향(A→B)만 제거
     * - 정책에 따라 양방향 모두 삭제할 수도 있음
     */
    public void deleteFriend(Long userId, Long friendId) {
        friendRepository.findByUserIdAndFriendId(userId, friendId)
                .ifPresent(friendRepository::delete);
    }

    /**
     * ✅ 친구 검색
     * --------------------------------
     * - 닉네임 또는 이메일 일부로 사용자 검색
     * - 자기 자신 제외
     * - 이미 친구인 경우 isFriend = true 반환
     */
    @Transactional(readOnly = true)
    public List<FriendSearchResponse> searchFriends(Long meId, String keyword) {
        List<User> candidates = userRepository.searchByNicknameOrEmail(keyword);

        return candidates.stream()
                .filter(u -> !u.getId().equals(meId)) // 자기 자신 제외
                .map(u -> FriendSearchResponse.builder()
                        .userId(u.getId())
                        .nickname(u.getNickname())
                        .email(u.getEmail())
                        .profileImageUrl(u.getProfileImageUrl())
                        .isFriend(friendRepository.existsByUserIdAndFriendId(meId, u.getId()))
                        .build()
                )
                .toList();
    }
}