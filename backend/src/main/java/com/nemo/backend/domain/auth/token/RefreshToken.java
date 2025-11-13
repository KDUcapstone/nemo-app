// backend/src/main/java/com/nemo/backend/domain/auth/token/RefreshToken.java
package com.nemo.backend.domain.auth.token;

import jakarta.persistence.*;
import lombok.Getter;

import java.time.LocalDateTime;

/**
 * 💡 RefreshToken 엔티티
 * 사용자의 리프레시 토큰 정보를 데이터베이스에 저장하는 클래스입니다.
 * - 각 사용자(userId)와 1:1로 매칭됩니다.
 * - 토큰 값(token)은 중복될 수 없으며, 유일(UNIQUE) 제약이 걸려 있습니다.
 * - 로그아웃 또는 계정 삭제 시 해당 사용자의 토큰은 삭제됩니다.
 */
@Getter
@Entity
@Table(
        name = "refresh_tokens", // 실제 테이블명
        indexes = {
                // userId로 조회할 때 속도를 높이기 위한 인덱스
                @Index(name = "ix_refresh_tokens_user", columnList = "userId")
        },
        uniqueConstraints = {
                // token 컬럼은 중복될 수 없도록 유니크 제약 설정
                @UniqueConstraint(name = "ux_refresh_tokens_token", columnNames = "token")
        }
)
public class RefreshToken {

    /** 기본 키 (자동 증가) */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 토큰이 속한 사용자 ID */
    @Column(nullable = false)
    private Long userId;

    /** 실제 리프레시 토큰 문자열 (UUID 또는 JWT 형태)
     *  중복 방지를 위해 UNIQUE 제약 적용 */
    @Column(nullable = false, unique = true, length = 512)
    private String token;

    /** 토큰 만료 일시 */
    @Column(nullable = false)
    private LocalDateTime expiry;

    // -----------------------------------
    // Getter / Setter
    // -----------------------------------
    public void setId(Long id) { this.id = id; }

    public void setUserId(Long userId) { this.userId = userId; }

    public void setToken(String token) { this.token = token; }

    public void setExpiry(LocalDateTime expiry) { this.expiry = expiry; }
}
