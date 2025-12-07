package com.nemo.backend.domain.auth.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nemo.backend.domain.album.repository.AlbumRepository;
import com.nemo.backend.domain.album.repository.AlbumShareRepository;
import com.nemo.backend.domain.auth.dto.GoogleLoginRequest;
import com.nemo.backend.domain.auth.dto.KakaoLoginRequest;
import com.nemo.backend.domain.auth.dto.*;
import com.nemo.backend.domain.auth.jwt.JwtUtil;
import com.nemo.backend.domain.auth.token.RefreshToken;
import com.nemo.backend.domain.auth.token.RefreshTokenRepository;
import com.nemo.backend.domain.user.entity.User;
import com.nemo.backend.domain.user.repository.UserRepository;
import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;
import com.nemo.backend.domain.album.entity.Album;
import com.nemo.backend.domain.album.entity.AlbumShare;
import com.nemo.backend.domain.album.repository.AlbumRepository;
import com.nemo.backend.domain.album.repository.AlbumShareRepository;
import com.nemo.backend.domain.album.repository.AlbumFavoriteRepository;
import com.nemo.backend.domain.friend.repository.FriendRepository;
import com.nemo.backend.domain.photo.entity.Photo;
import com.nemo.backend.domain.photo.repository.PhotoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@Transactional
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    // 🔽 새로 추가
    private final AlbumRepository albumRepository;
    private final AlbumShareRepository albumShareRepository;
    private final AlbumFavoriteRepository albumFavoriteRepository;
    private final FriendRepository friendRepository;
    private final PhotoRepository photoRepository;

    @Value("${jwt.access-exp-seconds:3600}")
    private long accessExpSeconds;

    @Value("${jwt.refresh-exp-days:14}")
    private long refreshExpDays;

    @Value("${jwt.refresh-rotate-threshold-sec:259200}")
    private long rotateThresholdSec;

    // 구글 ID 토큰의 aud 검증용 (없으면 스킵)
    @Value("${oauth.google.client-id:}")
    private String googleClientId;

    // =======================
    // 1) 회원가입
    // =======================
    public SignUpResponse signUp(SignUpRequest request) {

        if (request == null
                || request.getEmail() == null || request.getEmail().isBlank()
                || request.getPassword() == null || request.getPassword().isBlank()
                || request.getNickname() == null || request.getNickname().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "필수 정보가 누락되었습니다. (email, password, nickname)");
        }

        String email = request.getEmail().trim();

        if (userRepository.existsByEmail(email)) {
            throw new ApiException(ErrorCode.DUPLICATE_EMAIL);
        }

        User user = new User();
        user.setEmail(email);
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setNickname(request.getNickname().trim());  // ★ 필수
        user.setProfileImageUrl(request.getProfileImageUrl() != null ? request.getProfileImageUrl() : "");
        user.setProvider("local");
        user.setSocialId(null);

        User saved = userRepository.save(user);

        String createdAtStr = (saved.getCreatedAt() != null)
                ? saved.getCreatedAt().toString()
                : "";

        return new SignUpResponse(
                saved.getId(),
                saved.getEmail(),
                saved.getNickname(),
                saved.getProfileImageUrl(),
                createdAtStr
        );
    }

    // =======================
    // 2) 로그인
    // =======================
    public LoginResponse login(LoginRequest request) {

        if (request == null
                || request.getEmail() == null || request.getEmail().isBlank()
                || request.getPassword() == null || request.getPassword().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST);
        }

        User user = userRepository.findByEmail(request.getEmail().trim())
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_CREDENTIALS));

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new ApiException(ErrorCode.INVALID_CREDENTIALS);
        }

        // 로컬 로그인은 항상 isNewUser = false
        return createLoginResponse(user, false);
    }

    // =======================
    // 3) 로그아웃 (명세 반영)
    // =======================
    public void logout(Long userId, String refreshToken) {

        // ✅ 1) 리프레시 토큰이 아예 없으면 → 할 일이 없으니 그냥 반환 (에러 X)
        if (refreshToken == null || refreshToken.isBlank()) {
            return; // 이미 사실상 로그아웃 상태
        }

        RefreshToken stored = refreshTokenRepository.findByToken(refreshToken)
                .orElse(null);

        // ✅ 2) DB에 해당 토큰이 없으면 → 이미 삭제된 상태이므로 그냥 성공으로 처리
        if (stored == null) {
            return;
        }

        // ✅ 3) accessToken 이 있었다면, 그 사용자와 refreshToken 소유자가 일치하는지 검증
        if (userId != null && !stored.getUserId().equals(userId)) {
            throw new ApiException(ErrorCode.INVALID_TOKEN);
        }

        LocalDateTime now = LocalDateTime.now();

        // ✅ 4) 만료된 토큰이면 그냥 삭제하고 끝 (에러 안 던짐)
        if (stored.getExpiry() == null || !stored.getExpiry().isAfter(now)) {
            refreshTokenRepository.delete(stored);
            return;
        }

        // ✅ 5) 정상 토큰이면 해당 토큰만 삭제
        refreshTokenRepository.delete(stored);
    }

    /**
     * (기존 코드 사용 중이면 유지용 – 전체 토큰 삭제)
     */
    public void logoutAll(Long userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }

    // =======================
    // 4) 회원탈퇴
    // =======================
    public void deleteAccount(Long userId, String rawPassword) {

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));

        // ✅ 로컬 계정만 비밀번호 필수
        if ("local".equalsIgnoreCase(user.getProvider())) {
            if (rawPassword == null || rawPassword.isBlank()) {
                throw new ApiException(ErrorCode.INVALID_PASSWORD, "비밀번호가 필요합니다.");
            }

            if (!passwordEncoder.matches(rawPassword, user.getPassword())) {
                throw new ApiException(ErrorCode.INVALID_PASSWORD);
            }
        }
        // ✅ 소셜 계정(provider = kakao / google 등)은 비밀번호 검증 없이 그냥 진행

        // 🔥 1) 유저 관련 도메인 데이터 정리
        cleanupUserData(userId);

        // 🔥 2) 리프레시 토큰 삭제
        refreshTokenRepository.deleteByUserId(userId);

        // 🔥 3) 마지막으로 유저 삭제
        userRepository.delete(user);
    }

    // =======================
    // 5) Access Token 재발급
    // =======================
    @Transactional(readOnly = true)
    public RefreshResponse refresh(RefreshRequest request) {

        if (request == null
                || request.refreshToken() == null
                || request.refreshToken().isBlank()) {
            // 400 TOKEN_REQUIRED
            throw new ApiException(ErrorCode.TOKEN_REQUIRED);
        }

        RefreshToken stored = refreshTokenRepository.findByToken(request.refreshToken())
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_TOKEN));

        LocalDateTime now = LocalDateTime.now();

        // 만료 or 잘못된 토큰
        if (stored.getExpiry() == null || !stored.getExpiry().isAfter(now)) {
            refreshTokenRepository.delete(stored);
            throw new ApiException(ErrorCode.INVALID_TOKEN);
        }

        User user = userRepository.findById(stored.getUserId())
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));

        // 새 액세스 토큰 발급
        String newAccessToken = jwtUtil.createAccessToken(user.getId(), user.getEmail());

        // refreshToken 갱신 정책 (만료 임박 시 새로 발급)
        LocalDateTime expiry = stored.getExpiry();
        long totalSeconds = refreshExpDays * 24L * 60L * 60L;
        long remainingSeconds = java.time.Duration.between(now, expiry).getSeconds();

        String newRefreshToken = null;

        // 남은 시간이 전체의 1/3 이하라면 새 토큰 발급
        if (remainingSeconds < totalSeconds / 3) {
            String rotated = UUID.randomUUID().toString();
            stored.setToken(rotated);
            stored.setExpiry(now.plusDays(refreshExpDays));
            refreshTokenRepository.save(stored);
            newRefreshToken = rotated;
        }

        // 명세: refreshToken은 갱신된 경우만 포함
        return new RefreshResponse(newAccessToken, newRefreshToken);
    }

    // =======================
    // 내부 유틸: RefreshToken upsert
    // =======================
    private String upsertRefreshTokenForUser(Long userId) {

        LocalDateTime newExpiry = LocalDateTime.now().plusDays(refreshExpDays);

        return refreshTokenRepository.findFirstByUserId(userId)
                .map(entity -> {
                    entity.setToken(UUID.randomUUID().toString());
                    entity.setExpiry(newExpiry);
                    return entity.getToken();
                })
                .orElseGet(() -> {
                    RefreshToken refreshToken = new RefreshToken();
                    refreshToken.setUserId(userId);
                    refreshToken.setToken(UUID.randomUUID().toString());
                    refreshToken.setExpiry(newExpiry);
                    refreshTokenRepository.save(refreshToken);
                    return refreshToken.getToken();
                });
    }

    /**
     * 회원탈퇴 시 유저가 소유/참여 중인 도메인 데이터 정리
     * - 내가 소유한 앨범: 전부 삭제 (공유/개인 구분 없이)
     *   · 공유 앨범이면: 공유 멤버 전부 강퇴 후 앨범 삭제
     *   · 앨범 즐겨찾기(다른 유저가 누른 것도 포함) 전부 삭제
     * - 내가 초대받아 들어가 있는 공유 앨범: share 레코드만 제거(자동 탈퇴)
     * - 친구 관계: 나와 관련된 친구 관계 전부 삭제
     * - 내 사진: 전부 삭제(또는 soft delete)
     * - 내가 즐겨찾기한 앨범: 전부 삭제
     */
    private void cleanupUserData(Long userId) {

        // 0) 내가 즐겨찾기한 앨범 즐겨찾기 전부 삭제 (album_favorite.user_id = userId)
        albumFavoriteRepository.deleteAllByUserId(userId);

        // 1) 내가 멤버로 들어가 있는 공유 앨범에서 "나만" 탈퇴 (owner가 아닌 경우)
        var myShares = albumShareRepository.findAllByUserId(userId);

        for (AlbumShare share : myShares) {
            Album album = share.getAlbum();

            // Album 소유자는 album.getUser()
            Long ownerId = album.getUser().getId();

            // 내가 owner가 아닌 경우 → 공유 앨범 '나만' 탈퇴
            if (!ownerId.equals(userId)) {
                albumShareRepository.delete(share);
            }
        }

        // 2) 내가 소유한 앨범들 조회 (Album.user = 나)
        var myAlbums = albumRepository.findByUserId(userId);

        for (Album album : myAlbums) {
            Long albumId = album.getId();

            // 2-1) 이 앨범의 공유 멤버 전부 추방 (AlbumShare 삭제)
            albumShareRepository.deleteAllByAlbumId(albumId);

            // 2-2) 이 앨범이 즐겨찾기 된 내역 전부 삭제 (다른 유저가 즐겨찾기한 것도 포함)
            albumFavoriteRepository.deleteAllByAlbumId(albumId);

            // 2-3) 앨범-사진 매핑은 ManyToMany 이므로
            //      album 삭제 시 album_photos 조인 테이블 레코드는 자동으로 날아감 (FK+cascade)
            //      (별도 albumPhotoRepository 가 있으면 거기서 deleteAllByAlbumId 해도 됨)

            // 2-4) 앨범 삭제
            albumRepository.delete(album);
        }

        // 3) 친구 관계 전부 삭제 (내가 user이든 friend이든 전부)
        friendRepository.deleteAllByUserIdOrFriendId(userId, userId);

        // 4) 내 사진 전체 삭제 (soft delete or 물리 삭제 선택)
        //   - Photo 엔티티에 deleted 플래그 있으니까 soft delete로 처리 예시
        var myPhotos = photoRepository.findAllByUserId(userId);
        for (Photo photo : myPhotos) {
            photo.setDeleted(true);     // 소프트 삭제
            // photo.setFavorite(false); // 즐겨찾기도 동시에 해제하고 싶으면 포함
        }

        // 만약 진짜 DB에서 사진 레코드를 없애고 싶다면:
        // photoRepository.deleteAll(myPhotos);
    }


    private LoginResponse createLoginResponse(User user, boolean isNewUser) {
        String accessToken = jwtUtil.createAccessToken(user.getId(), user.getEmail());
        String refreshTokenStr = upsertRefreshTokenForUser(user.getId());

        String nickname = user.getNickname() != null ? user.getNickname() : "";
        String profile = user.getProfileImageUrl() != null ? user.getProfileImageUrl() : "";
        String provider = (user.getProvider() != null ? user.getProvider() : "local");

        return new LoginResponse(
                accessToken,
                refreshTokenStr,
                accessExpSeconds,
                isNewUser,
                user.getId(),
                nickname,
                profile,
                provider      // 👈 여기 추가
        );
    }

    private String buildSocialEmail(String provider, String socialId, String emailFromProvider) {
        String email = (emailFromProvider != null && !emailFromProvider.isBlank())
                ? emailFromProvider.trim()
                : null;

        // 이메일이 없거나 이미 사용 중이면 provider/socialId 기반 가짜 이메일 생성
        if (email == null || userRepository.existsByEmail(email)) {
            email = provider + "_" + socialId + "@oauth.nemo";
        }
        return email;
    }

    private LoginResponse processSocialLogin(String provider,
                                             String socialId,
                                             String emailFromProvider,
                                             String nicknameFromProvider,
                                             String profileImageUrlFromProvider) {

        if (socialId == null || socialId.isBlank()) {
            if ("kakao".equals(provider)) {
                throw new ApiException(ErrorCode.INVALID_KAKAO_TOKEN);
            } else if ("google".equals(provider)) {
                throw new ApiException(ErrorCode.INVALID_GOOGLE_TOKEN);
            } else {
                throw new ApiException(ErrorCode.INVALID_TOKEN);
            }
        }

        // 1) 기존 SNS 계정 있는지
        User user = userRepository.findByProviderAndSocialId(provider, socialId)
                .orElse(null);

        boolean isNewUser = false;

        if (user == null) {
            // 2) 없으면 "최초 로그인" → 자동 회원가입
            String email = buildSocialEmail(provider, socialId, emailFromProvider);

            user = new User();
            user.setEmail(email);
            user.setPassword(passwordEncoder.encode(UUID.randomUUID().toString())); // 랜덤 비번
            user.setNickname(
                    (nicknameFromProvider != null && !nicknameFromProvider.isBlank())
                            ? nicknameFromProvider.trim()
                            : provider + "_user"
            );
            user.setProfileImageUrl(
                    (profileImageUrlFromProvider != null) ? profileImageUrlFromProvider : ""
            );
            user.setProvider(provider);
            user.setSocialId(socialId);

            user = userRepository.save(user);
            isNewUser = true;
        }
        // 🔹 else 블록에서 더 이상 nickname/profileImageUrl 을 소셜 값으로 덮어쓰지 않음
        //    → 이후 프로필 변경은 전부 우리 서비스(마이페이지 수정 API)만 사용

        return createLoginResponse(user, isNewUser);
    }

    // =======================
    // SNS 로그인 - Kakao
    // =======================
    public LoginResponse loginWithKakao(KakaoLoginRequest request) {
        if (request == null || request.getAccessToken() == null || request.getAccessToken().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "accessToken 은 필수입니다.");
        }

        String accessToken = request.getAccessToken().trim();

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(
                    "https://kapi.kakao.com/v2/user/me",
                    HttpMethod.GET,
                    entity,
                    String.class
            );

            JsonNode root = objectMapper.readTree(response.getBody());
            String kakaoId = root.path("id").asText(null);

            JsonNode account = root.path("kakao_account");
            JsonNode profile = account.path("profile");

            String email = account.path("email").asText(null);
            String nickname = profile.path("nickname").asText("");
            String profileImageUrl = profile.path("profile_image_url").asText("");

            return processSocialLogin("kakao", kakaoId, email, nickname, profileImageUrl);
        } catch (HttpClientErrorException e) {
            // 401 / 403 등 → 명세상 INVALID_KAKAO_TOKEN
            throw new ApiException(ErrorCode.INVALID_KAKAO_TOKEN);
        } catch (Exception e) {
            // 파싱 에러 등도 일단 토큰 불량 취급
            throw new ApiException(ErrorCode.INVALID_KAKAO_TOKEN);
        }
    }

    // =======================
    // SNS 로그인 - Google
    // =======================
    public LoginResponse loginWithGoogle(GoogleLoginRequest request) {
        if (request == null || request.getIdToken() == null || request.getIdToken().isBlank()) {
            throw new ApiException(ErrorCode.INVALID_REQUEST, "idToken 은 필수입니다.");
        }

        String idToken = request.getIdToken().trim();

        try {
            // https://oauth2.googleapis.com/tokeninfo?id_token=...
            String uri = UriComponentsBuilder
                    .fromHttpUrl("https://oauth2.googleapis.com/tokeninfo")
                    .queryParam("id_token", idToken)
                    .build(true)
                    .toUriString();

            ResponseEntity<String> response = restTemplate.getForEntity(uri, String.class);
            JsonNode root = objectMapper.readTree(response.getBody());

            String sub = root.path("sub").asText(null);        // Google user ID
            String email = root.path("email").asText(null);
            String name = root.path("name").asText("");
            String picture = root.path("picture").asText("");

            // aud 검증 (clientId 설정돼 있을 때만)
            String aud = root.path("aud").asText(null);
            if (googleClientId != null && !googleClientId.isBlank()
                    && aud != null && !googleClientId.equals(aud)) {
                throw new ApiException(ErrorCode.INVALID_GOOGLE_TOKEN, "클라이언트 ID가 일치하지 않습니다.");
            }

            return processSocialLogin("google", sub, email, name, picture);
        } catch (HttpClientErrorException e) {
            throw new ApiException(ErrorCode.INVALID_GOOGLE_TOKEN);
        } catch (Exception e) {
            throw new ApiException(ErrorCode.INVALID_GOOGLE_TOKEN);
        }
    }
}
