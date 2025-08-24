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
  Future<bool> signup() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await AuthService().signup(signupForm);
      isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
