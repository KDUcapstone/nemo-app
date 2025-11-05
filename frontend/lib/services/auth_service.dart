import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../app/constants.dart';
import '../presentation/screens/login/signup_form_model.dart';
import 'api_client.dart';

class AuthService {
  // ✅ 서버 URL 설정 (로컬 or 배포 서버로 교체해야 함)
  static const String baseUrl =
      'http://10.0.2.2:8080'; // ← TODO: 실제 주소로 바꿔!

  // JWT 토큰 저장소
  static String? _accessToken;

  static String? get accessToken => _accessToken;

  // JWT 토큰 설정
  static void setAccessToken(String token) {
    _accessToken = token;
  }

  // JWT 토큰 제거
  static void clearAccessToken() {
    _accessToken = null;
  }

  // JWT 토큰이 포함된 헤더 생성
  static Map<String, String> _getHeaders({bool includeAuth = true}) {
    return ApiClient.headers(includeAuth: includeAuth);
  }

  /// 로그인 요청
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (AppConstants.useMockApi) {
      // 모킹 응답
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      // 간단 검증
      if (email.isEmpty || password.isEmpty) {
        throw Exception('이메일 또는 비밀번호가 올바르지 않습니다.');
      }
      final mockToken =
          'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
      setAccessToken(mockToken);
      return {
        'success': true,
        'accessToken': mockToken,
        'userId': 1,
        'nickname': '네컷러버',
        'profileImageUrl': null,
      };
    }
    try {
      final response = await ApiClient.post(
        '/api/users/login',
        body: {'email': email, 'password': password},
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // 로그인 성공 시 토큰 저장
        final access = data['accessToken'] as String;
        setAccessToken(access);
        return {
          'success': true,
          'accessToken': access,
          'refreshToken': data['refreshToken'] as String?,   // 있으면 저장에 사용
          'userId': (data['id'] as num).toInt(),             // ← 안전 파싱
          'nickname': data['nickname'] as String? ?? '',
          'profileImageUrl': data['profileImageUrl'],        // null 허용
        };
      } else if (response.statusCode == 401) {
        throw Exception('이메일 또는 비밀번호가 올바르지 않습니다.');
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? '잘못된 요청입니다.');
      } else {
        throw Exception('로그인 실패 (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 회원가입 요청
  Future<bool> signup(SignupFormModel form) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      // 간단한 중복 이메일/유효성 모의 검증
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(form.email)) {
        throw Exception('올바른 이메일 형식을 입력해주세요');
      }
      if (form.password.length < 8 ||
          !RegExp(r'[A-Za-z]').hasMatch(form.password) ||
          !RegExp(r'\d').hasMatch(form.password) ||
          !RegExp(r'[^A-Za-z0-9]').hasMatch(form.password)) {
        throw Exception('비밀번호는 영문, 숫자, 특수문자를 포함해 8자 이상이어야 합니다.');
      }
      if (form.nickname.trim().isEmpty) {
        throw Exception('닉네임을 입력해주세요');
      }
      // 중복 이메일 더미 체크
      if (form.email.toLowerCase() == 'exists@example.com') {
        throw Exception('이미 존재하는 이메일입니다.');
      }
      return true;
    }
    try {
      final response = await ApiClient.post(
        '/api/users/signup',
        includeAuth: false,
        body: {
          'email': form.email,
          'password': form.password,
          'nickname': form.nickname,
        },
      );

      if (response.statusCode == 201) {
        // 성공적으로 회원가입 완료
        return true;
      } else if (response.statusCode == 409) {
        throw Exception('이미 존재하는 이메일입니다.');
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? '잘못된 요청입니다.');
      } else {
        throw Exception('회원가입 실패 (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 이메일 인증 메일 발송
  Future<void> sendEmailVerification(String email) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return;
    }
    try {
      final response = await ApiClient.post(
        '/api/auth/email/verification/send',
        includeAuth: false,
        body: {'email': email},
      );
      if (response.statusCode != 200) {
        if (response.statusCode == 429) {
          throw Exception('요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
        }
        final body = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;
        throw Exception(
          body != null && body['message'] != null
              ? body['message']
              : '인증 메일 발송 실패 (${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 이메일 인증 코드 확인
  Future<bool> confirmEmailVerification({
    required String email,
    required String code,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (code.trim() != '123456') {
        throw Exception('인증 코드가 올바르지 않습니다.');
      }
      return true;
    }
    try {
      final response = await ApiClient.post(
        '/api/auth/email/verification/confirm',
        includeAuth: false,
        body: {'email': email, 'code': code},
      );
      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 400) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? '인증 코드가 올바르지 않습니다.');
      } else {
        throw Exception('인증 확인 실패 (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 사용자 정보 조회 (JWT 토큰 필요)
  Future<Map<String, dynamic>> getUserInfo() async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (_accessToken == null) {
        throw Exception('인증이 필요합니다.');
      }
      return {
        'userId': 1,
        'email': 'user@example.com',
        'nickname': '네컷러버',
        'profileImageUrl': null,
        'createdAt': DateTime.now().toIso8601String(),
      };
    }
    try {
      final response = await ApiClient.get('/api/users/me');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('인증이 필요합니다.');
      } else {
        throw Exception('사용자 정보 조회 실패 (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 로그아웃 (JWT 토큰 무효화)
  Future<bool> logout() async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      clearAccessToken();
      return true;
    }
    try {
      final response = await ApiClient.post('/api/users/logout');

      if (response.statusCode == 200) {
        // 로컬 토큰 제거
        clearAccessToken();
        return true;
      } else {
        throw Exception('로그아웃 실패 (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 회원탈퇴 (비밀번호 확인 필요)
  Future<bool> deleteAccount(String password) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (password.isEmpty) {
        throw Exception('비밀번호가 올바르지 않습니다.');
      }
      clearAccessToken();
      return true;
    }
    try {
      final response = await http.delete(
        ApiClient.uri('/api/users/me'),
        headers: _getHeaders(),
        body: jsonEncode({'password': password}),
      );

      if (response.statusCode == 200) {
        // 로컬 토큰 제거
        clearAccessToken();
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('비밀번호가 올바르지 않습니다.');
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? '잘못된 요청입니다.');
      } else {
        throw Exception('회원탈퇴 실패 (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 로그인 상태 비밀번호 변경
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (AuthService.accessToken == null) {
        throw Exception('UNAUTHORIZED');
      }
      if (newPassword != confirmPassword) {
        throw Exception('PASSWORD_CONFIRM_MISMATCH');
      }
      if (currentPassword == newPassword) {
        throw Exception('PASSWORD_POLICY_VIOLATION');
      }
      final meetsPolicy = () {
        if (newPassword.length < 8 || newPassword.length > 64) return false;
        bool hasLetter = RegExp(r'[A-Za-z]').hasMatch(newPassword);
        bool hasDigit = RegExp(r'\d').hasMatch(newPassword);
        bool hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(newPassword);
        final count = [hasLetter, hasDigit, hasSpecial].where((e) => e).length;
        return count >= 2;
      }();
      if (!meetsPolicy) {
        throw Exception('PASSWORD_POLICY_VIOLATION');
      }
      // 모킹: 현재 비밀번호 불일치 에러 시뮬레이션(특정 값만 실패)
      if (currentPassword == 'wrong-pass') {
        throw Exception('INVALID_CURRENT_PASSWORD');
      }
      return '비밀번호가 성공적으로 변경되었습니다. 다시 로그인해주세요.';
    }
    try {
      final response = await ApiClient.put(
        '/api/users/me/password',
        body: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return (body is Map && body['message'] is String)
            ? body['message'] as String
            : '비밀번호가 성공적으로 변경되었습니다. 다시 로그인해주세요.';
      }
      if (response.statusCode == 401) {
        throw Exception('UNAUTHORIZED');
      }
      if (response.statusCode == 403) {
        throw Exception('INVALID_CURRENT_PASSWORD');
      }
      if (response.statusCode == 400) {
        final body = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;
        final err = body is Map ? (body['error'] as String?) : null;
        if (err == 'PASSWORD_CONFIRM_MISMATCH') {
          throw Exception('PASSWORD_CONFIRM_MISMATCH');
        }
        if (err == 'PASSWORD_POLICY_VIOLATION') {
          throw Exception('PASSWORD_POLICY_VIOLATION');
        }
        throw Exception('BAD_REQUEST');
      }
      throw Exception('CHANGE_PASSWORD_FAILED_${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }
}
