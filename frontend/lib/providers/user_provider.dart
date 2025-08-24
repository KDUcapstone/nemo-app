import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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
  }) {
    this.userId = userId;
    this.nickname = nickname;
    this.profileImageUrl = profileImageUrl;
    this.accessToken = accessToken;

    // AuthService에도 토큰 저장
    AuthService.setAccessToken(accessToken);

    notifyListeners();
  }

  void logout() {
    userId = null;
    nickname = null;
    profileImageUrl = null;
    accessToken = null;

    // AuthService에서도 토큰 제거
    AuthService.clearAccessToken();

    notifyListeners();
  }
}
