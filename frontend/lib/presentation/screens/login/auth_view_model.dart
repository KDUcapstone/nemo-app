// lib/presentation/screens/login/auth_view_model.dart

import 'package:flutter/material.dart';
import 'signup_form_model.dart';
import 'package:frontend/services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  // 회원가입용 폼 데이터
  SignupFormModel signupForm = SignupFormModel(
    email: '',
    password: '',
    nickname: '',
  );

  bool isLoading = false;
  String? errorMessage;

  // 사용자 입력값 변경 함수
  void setEmail(String value) {
    signupForm.email = value;
    notifyListeners();
  }

  void setPassword(String value) {
    signupForm.password = value;
    notifyListeners();
  }

  void setNickname(String value) {
    signupForm.nickname = value;
    notifyListeners();
  }

  void setProfileImageUrl(String? url) {
    signupForm.profileImageUrl = url;
    notifyListeners();
  }

  // 회원가입 요청 함수
  // AuthService.signup()은 Map<String, dynamic>을 반환하고, 이 함수는 성공 여부(bool)만 반환
  Future<bool> signup() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // API 명세서: AuthService.signup()은 Map<String, dynamic> 반환 (userId, email, nickname, profileImageUrl, createdAt 포함)
      final result = await AuthService().signup(signupForm);
      isLoading = false;
      notifyListeners();
      // userId가 있으면 성공
      return result['userId'] != null;
    } catch (e) {
      final errorMsg = e.toString();
      // Exception: 접두사 제거
      if (errorMsg.startsWith('Exception: ')) {
        errorMessage = errorMsg.substring('Exception: '.length);
      } else {
        errorMessage = '회원가입에 실패했습니다.';
      }
      isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
