import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'photo_provider.dart';
import 'album_provider.dart';

class UserProvider extends ChangeNotifier {
  int? userId;
  String? nickname;
  String? profileImageUrl;
  String? accessToken;

  bool get isLoggedIn => accessToken != null;

  void setUser({
    required int userId,
    required String nickname,
    required String accessToken,
    String? profileImageUrl,
    BuildContext? context,
  }) {
    this.userId = userId;
    this.nickname = nickname;
    this.profileImageUrl = profileImageUrl;
    this.accessToken = accessToken;

    // AuthService에도 토큰 저장
    AuthService.setAccessToken(accessToken);

    notifyListeners();

    // 로그인 시 다른 Provider 초기화 및 새로고침
    if (context != null) {
      _resetOtherProviders(context);
      _refreshOtherProviders(context);
    }
  }

  void logout({BuildContext? context}) {
    userId = null;
    nickname = null;
    profileImageUrl = null;
    accessToken = null;

    // AuthService에서도 토큰 제거
    AuthService.clearAccessToken();

    notifyListeners();

    // 로그아웃 시 다른 Provider 초기화
    if (context != null) {
      _resetOtherProviders(context);
    }
  }

  void _resetOtherProviders(BuildContext context) {
    try {
      final photoProvider = Provider.of<PhotoProvider>(context, listen: false);
      photoProvider.reset();
      final albumProvider = Provider.of<AlbumProvider>(context, listen: false);
      albumProvider.reset();
    } catch (e) {
      // Provider가 없을 수 있으므로 무시
    }
  }

  void _refreshOtherProviders(BuildContext context) {
    try {
      final photoProvider = Provider.of<PhotoProvider>(context, listen: false);
      photoProvider.fetchListIfNeeded();
      final albumProvider = Provider.of<AlbumProvider>(context, listen: false);
      albumProvider.resetAndLoad();
      // 로그인 시 공유 앨범 권한 정보도 새로고침
      albumProvider.refreshSharedAlbums();
    } catch (e) {
      // Provider가 없을 수 있으므로 무시
    }
  }
}
