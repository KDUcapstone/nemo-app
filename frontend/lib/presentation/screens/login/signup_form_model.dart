// lib/presentation/screens/login/signup_form_model.dart

class SignupFormModel {
  String email;
  String password;
  String nickname;
  String? profileImageUrl;

  SignupFormModel({
    required this.email,
    required this.password,
    required this.nickname,
    this.profileImageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
    };
  }
}
