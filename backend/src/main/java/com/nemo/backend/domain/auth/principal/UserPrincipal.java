package com.nemo.backend.domain.auth.principal;

import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;

/**
 * ✅ 인증된 사용자 정보를 담는 클래스 (시큐리티 컨텍스트에 저장됨)
 * - 컨트롤러에서 @AuthenticationPrincipal 로 바로 받을 수 있음
 * - 엔티티(User) 직접 들고 다니지 말고, 필요한 최소 정보만(예: id, email) 보관
 */
@Getter
@AllArgsConstructor
public class UserPrincipal implements UserDetails {
    private final Long id;      // 👉 우리 서비스에서 가장 많이 쓰는 키: userId
    private final String email; // 👉 필요하면 추가, 아니면 null 허용

    // 아래는 스프링 시큐리티 표준 인터페이스 구현 (우린 권한/패스워드 안 씀)
    @Override public Collection<? extends GrantedAuthority> getAuthorities() { return null; }
    @Override public String getPassword() { return null; }  // 비번 인증은 JWT가 대신함
    @Override public String getUsername() { return email; } // 화면상 식별자 용도
    @Override public boolean isAccountNonExpired() { return true; }
    @Override public boolean isAccountNonLocked() { return true; }
    @Override public boolean isCredentialsNonExpired() { return true; }
    @Override public boolean isEnabled() { return true; }
}
