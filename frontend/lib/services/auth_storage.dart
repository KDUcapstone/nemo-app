import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 리프레시 토큰 & 사용자 기본 정보를 로컬에 안전하게 저장/로드하는 유틸
class AuthStorage {
  static const _storage = FlutterSecureStorage();

  static const _keyUserId = 'auth_user_id';
  static const _keyNickname = 'auth_nickname';
  static const _keyProfileImageUrl = 'auth_profile_image_url';
  static const _keyRefreshToken = 'auth_refresh_token';
  static const _keyProvider = 'auth_provider';     // ★ 추가

  /// 로그인 성공 시 호출: 리프레시 토큰 + 유저 정보 저장
  static Future<void> saveAuth({
    required int userId,
    required String nickname,
    String? profileImageUrl,
    required String refreshToken,
    required String? provider,                     // ★ 추가
  }) async {
    await _storage.write(key: _keyUserId, value: userId.toString());
    await _storage.write(key: _keyNickname, value: nickname);
    await _storage.write(key: _keyProfileImageUrl, value: profileImageUrl);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
    await _storage.write(key: _keyProvider, value: provider ?? 'local'); // ★ 추가
  }

  /// 저장된 refreshToken과 유저 기본 정보 로드
  static Future<StoredAuth?> loadAuth() async {
    final token = await _storage.read(key: _keyRefreshToken);
    if (token == null || token.isEmpty) {
      return null;
    }
    final userIdStr = await _storage.read(key: _keyUserId);
    final nickname = await _storage.read(key: _keyNickname) ?? '';
    final profileImageUrl =
    await _storage.read(key: _keyProfileImageUrl);
    final provider = await _storage.read(key: _keyProvider);     // ★ 추가

    final userId = int.tryParse(userIdStr ?? '');
    if (userId == null) return null;

    return StoredAuth(
      userId: userId,
      nickname: nickname,
      profileImageUrl: profileImageUrl,
      refreshToken: token,
      provider: provider,                                     // ★ 추가
    );
  }

  /// 로그아웃/탈퇴 시 저장된 값 제거
  static Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _keyUserId),
      _storage.delete(key: _keyNickname),
      _storage.delete(key: _keyProfileImageUrl),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyProvider),          // ★ 추가
    ]);
  }
}

class StoredAuth {
  final int userId;
  final String nickname;
  final String? profileImageUrl;
  final String refreshToken;
  final String? provider;   // local/kakao/google

  StoredAuth({
    required this.userId,
    required this.nickname,
    required this.profileImageUrl,
    required this.refreshToken,
    required this.provider,
  });
}


