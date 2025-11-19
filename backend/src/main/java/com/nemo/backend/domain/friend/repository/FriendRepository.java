package com.nemo.backend.domain.friend.repository;

import com.nemo.backend.domain.friend.entity.Friend;
import com.nemo.backend.domain.friend.entity.FriendStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

/**
 * FriendRepository
 * -------------------------
 * - Friend 엔티티와 데이터베이스를 연결하는 JPA 인터페이스
 * - JPA가 메서드 이름을 보고 자동으로 SQL 쿼리를 만들어줌
 *   예: existsByUserIdAndFriendId() → SELECT COUNT(*) FROM friend WHERE user_id=? AND friend_id=?
 */
public interface FriendRepository extends JpaRepository<Friend, Long> {

    /**
     * 두 사용자가 친구 관계인지 확인
     * -----------------------------
     * - user_id와 friend_id가 이미 존재하면 true 반환
     * - 이미 친구 요청을 보냈거나 수락된 상태인지 확인할 때 사용
     */
    boolean existsByUserIdAndFriendId(Long userId, Long friendId);

    /**
     * 특정 사용자의 친구 목록 조회
     * -----------------------------
     * - user_id가 나(me)인 레코드 중
     * - status(상태)가 특정 상태(PENDING, ACCEPTED 등)인 친구만 반환
     * 예: 나의 수락된 친구 목록 → findAllByUserIdAndStatus(meId, ACCEPTED)
     */
    List<Friend> findAllByUserIdAndStatus(Long userId, FriendStatus status);

    /**
     * 두 사용자 간의 친구 관계 조회
     * -----------------------------
     * - user_id와 friend_id를 동시에 조건으로 조회
     * - 친구 관계를 수정하거나 삭제할 때 주로 사용
     * 예: 특정 친구 요청을 수락하거나 취소할 때
     */
    Optional<Friend> findByUserIdAndFriendId(Long userId, Long friendId);

    /**
     * 두 사용자 사이에 특정 상태(FriendStatus)의 관계가 존재하는지 여부
     */
    boolean existsByUserIdAndFriendIdAndStatus(Long userId, Long friendId, FriendStatus status);

    /**
     * 특정 사용자가 친구로 등록한 사용자들 중에서 특정 상태(FriendStatus)를 가진 친구 목록 조회
     */
    List<Friend> findAllByFriendIdAndStatus(Long friendId, FriendStatus status);

}
