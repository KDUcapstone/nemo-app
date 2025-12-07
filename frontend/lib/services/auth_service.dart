import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../app/constants.dart';
import 'api_client.dart';
import 'auth_storage.dart';

class AutoLoginResult {
  final bool success;
  final int? userId;
  final String? nickname;
  final String? profileImageUrl;
  final String? accessToken;
  final String? provider;           // ★ 추가

  AutoLoginResult({
    required this.success,
    this.userId,
    this.nickname,
    this.profileImageUrl,
    this.accessToken,
    this.provider,                  // ★ 추가
  });
}

/// 계정 잠금 예외 (비밀번호 재설정 필요)
class AccountLockedException implements Exception {
  final String message;
  final int? remainingAttempts;
  final String? email;

  AccountLockedException({
    required this.message,
    this.remainingAttempts,
    this.email,
  });

  @override
  String toString() => message;
}

/// 캡챠 필요 예외 (Turnstile 인증 필요)
class NeedCaptchaException implements Exception {
  final String message;
  final int? remainingAttempts;

  NeedCaptchaException({required this.message, this.remainingAttempts});

  @override
  String toString() => message;
}

class AuthService {
  // ✅ 서버 URL 설정 (health 체크 기반 원격/로컬 자동 선택)
  static String? _resolvedBaseUrl;

  // 원격/로컬 후보 URL
  static const String _remoteBaseUrl =
      'https://port-0-nemo-docker-springboot-prod-mdy7o3aya1eb5a01.sel5.cloudtype.app/';
  static const String _localBaseUrlAndroid = 'http://localhost:8080/';
  static const String _localBaseUrlDefault = 'http://localhost:8080/';

  // 외부에서 사용하는 baseUrl (초기화 전에는 원격 기본값 사용)
  static String get baseUrl => _resolvedBaseUrl ?? _remoteBaseUrl;

  /// 앱 시작 시 한 번 호출해서 baseUrl을 결정
  static Future<void> initBaseUrl() async {
    if (_resolvedBaseUrl != null) return; // 이미 결정된 경우 재실행 방지

    // 1) 원격 서버 health 체크 시도
    try {
      final uri = Uri.parse('${_remoteBaseUrl}actuator/health');
      // 모바일 네트워크 환경에서도 여유를 두기 위해 타임아웃을 7초로 증가
      final res = await http.get(uri).timeout(const Duration(seconds: 7));

      if (res.statusCode >= 200 && res.statusCode < 400) {
        _resolvedBaseUrl = _remoteBaseUrl;
        print('🌐 [AuthService] 원격 서버 사용: $_resolvedBaseUrl');
        return;
      }
    } catch (e) {
      print('🌐 [AuthService] 원격 서버 health 체크 실패: $e');
    }

    // 2) 실패 시 로컬 서버로 fallback
    if (Platform.isAndroid) {
      _resolvedBaseUrl = _localBaseUrlAndroid;
    } else {
      _resolvedBaseUrl = _localBaseUrlDefault;
    }
    print('🌐 [AuthService] 로컬 서버 사용: $_resolvedBaseUrl');
  }

  // JWT 토큰 저장소
  static String? _accessToken;
  static String? _refreshToken;

  static String? get accessToken => _accessToken;
  static String? get refreshToken => _refreshToken;

  // JWT Access Token 설정
  static void setAccessToken(String token) {
    _accessToken = token;
  }

  // JWT Refresh Token 설정
  static void setRefreshToken(String token) {
    _refreshToken = token;
  }

  // JWT 토큰 제거 (Access Token과 Refresh Token 모두 제거)
  static void clearAccessToken() {
    _accessToken = null;
    _refreshToken = null;
  }

  /// 앱 시작 시 로컬에 저장된 refreshToken을 사용해 자동 로그인 시도
  /// - 성공 시: accessToken 갱신 + (필요하면 refreshToken 갱신)
  /// - 실패 시: 저장값 삭제
  static Future<AutoLoginResult> tryAutoLogin() async {
    try {
      final stored = await AuthStorage.loadAuth();
      if (stored == null) {
        return AutoLoginResult(success: false);
      }

      // 서버에 refresh 토큰 검증 + accessToken 발급 요청
      final refreshRes = await ApiClient.post(
        '/api/auth/refresh',
        body: {'refreshToken': stored.refreshToken},
        includeAuth: false,
      );

      if (refreshRes.statusCode != 200) {
        await AuthStorage.clear();
        return AutoLoginResult(success: false);
      }

      final data =
      jsonDecode(utf8.decode(refreshRes.bodyBytes)) as Map<String, dynamic>;
      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;

      if (newAccess == null || newAccess.isEmpty) {
        await AuthStorage.clear();
        return AutoLoginResult(success: false);
      }

      // 메모리에 토큰 반영
      setAccessToken(newAccess);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        setRefreshToken(newRefresh);
        await AuthStorage.saveAuth(
          userId: stored.userId,
          nickname: stored.nickname,
          profileImageUrl: stored.profileImageUrl,
          refreshToken: newRefresh,
          provider: stored.provider,           // ★ 추가
        );
      } else {
        // refreshToken 변경 없으면 기존 값 유지
        _refreshToken = stored.refreshToken;
      }

      return AutoLoginResult(
        success: true,
        userId: stored.userId,
        nickname: stored.nickname,
        profileImageUrl: stored.profileImageUrl,
        accessToken: newAccess,
        provider: stored.provider,   // ★ 여기 추가
      );
    } catch (_) {
      await AuthStorage.clear();
      return AutoLoginResult(success: false);
    }
  }

  // JWT 토큰이 포함된 헤더 생성
  static Map<String, String> _getHeaders({bool includeAuth = true}) {
    return ApiClient.headers(includeAuth: includeAuth);
  }

  /// 로그인 요청
  Future<Map<String, dynamic>> login(
      String email,
      String password, {
        String? turnstileToken,
      }) async {
    if (AppConstants.useMockApi) {
      // 모킹 응답
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      // 간단 검증
      if (email.isEmpty || password.isEmpty) {
        throw Exception('이메일 또는 비밀번호가 올바르지 않습니다.');
      }
      // API 명세서: { accessToken, refreshToken, expiresIn, user: { userId, nickname, profileImageUrl } }
      final mockToken =
          'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
      final mockRefreshToken =
          'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';
      setAccessToken(mockToken);
      setRefreshToken(mockRefreshToken);
      // API 명세서와 일치하도록 user 객체와 최상위 필드 모두 포함
      final mockUser = {
        'userId': 1,
        'nickname': '네컷러버',
        'profileImageUrl': null,
      };
      return {
        'accessToken': mockToken,
        'refreshToken': mockRefreshToken,
        'expiresIn': 3600,
        'user': mockUser,
        // 실제 API 응답과 동일하게 최상위에도 포함
        'userId': 1,
        'nickname': '네컷러버',
        'profileImageUrl': null,
      };
    }
    try {
      // 디버그 로그 추가
      print('🔵 [LOGIN] 시작 - baseUrl: $baseUrl');
      print('🔵 [LOGIN] useMockApi: ${AppConstants.useMockApi}');
      print('🔵 [LOGIN] 요청 URL: ${baseUrl}api/users/login');

      final body = <String, dynamic>{'email': email, 'password': password};

      // turnstileToken이 있으면 추가
      if (turnstileToken != null && turnstileToken.isNotEmpty) {
        body['turnstileToken'] = turnstileToken;
      }

      final response = await ApiClient.post(
        '/api/users/login',
        body: body,
        includeAuth: false,
      );

      print('🟢 [LOGIN] 응답 상태: ${response.statusCode}');
      print('🟢 [LOGIN] 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        // API 명세서: { accessToken, refreshToken, expiresIn, user: { userId, nickname, profileImageUrl } }
        // UTF-8로 명시적으로 디코딩하여 인코딩 문제 방지
        final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final access = data['accessToken'] as String;
        final refresh = data['refreshToken'] as String?;
        final user = data['user'] as Map<String, dynamic>?;
        final provider = user?['provider'] as String? ?? 'local';   // ★ 추가

        // Access Token과 Refresh Token 저장 + 로컬 저장
        setAccessToken(access);
        if (refresh != null) {
          setRefreshToken(refresh);
          final uid = (user?['userId'] as num?)?.toInt();
          final nickname = user?['nickname'] as String? ?? '';
          final profileImageUrl = user?['profileImageUrl'] as String?;
          if (uid != null) {
            // 실패해도 로그인 자체에는 영향 없도록 await 사용
            await AuthStorage.saveAuth(
              userId: uid,
              nickname: nickname,
              profileImageUrl: profileImageUrl,
              refreshToken: refresh,
              provider: provider,           // ★ 추가
            );
          }
        }

        return {
          'accessToken': access,
          'refreshToken': refresh,
          'expiresIn': data['expiresIn'] as int? ?? 3600,
          'user': user ?? {},
          'userId': (user?['userId'] as num?)?.toInt(),
          'nickname': user?['nickname'] as String? ?? '',
          'profileImageUrl': user?['profileImageUrl'],
          'provider': provider,   // ★ 추가
        };
      } else if (response.statusCode == 401) {
        // 백엔드 명세: { "error": "INVALID_CREDENTIALS", "message": "...", "remainingAttempts": 3, "needCaptcha": false, "needPasswordReset": false }
        final raw = response.body.isNotEmpty
            ? utf8.decode(response.bodyBytes)
            : '';
        Map<String, dynamic>? data;
        try {
          data = raw.isNotEmpty
              ? jsonDecode(raw) as Map<String, dynamic>
              : null;
        } catch (_) {
          data = null;
        }
        final error = data?['error'] as String?;
        final message = data?['message'] as String?;
        final remainingAttempts = data?['remainingAttempts'] as int?;
        final needPasswordReset = data?['needPasswordReset'] as bool? ?? false;
        final needCaptcha = data?['needCaptcha'] as bool? ?? false;

        // 계정 잠금 또는 비밀번호 재설정 필요
        if (error == 'ACCOUNT_LOCKED' || needPasswordReset == true) {
          throw AccountLockedException(
            message: message?.isNotEmpty == true
                ? message!
                : '비밀번호를 여러 번 틀려 계정이 잠겼습니다. 비밀번호를 재설정해주세요.',
            remainingAttempts: remainingAttempts,
            email: email, // 로그인 시도한 이메일 전달
          );
        }

        // 캡챠 필요 또는 캡챠 검증 실패
        if (error == 'NEED_CAPTCHA' ||
            error == 'INVALID_CAPTCHA' ||
            needCaptcha == true) {
          throw NeedCaptchaException(
            message: message?.isNotEmpty == true
                ? message!
                : error == 'INVALID_CAPTCHA'
                ? '캡챠 인증에 실패했습니다. 다시 시도해주세요.'
                : '비밀번호를 여러 번 틀렸습니다. 캡챠 인증을 완료한 후 다시 시도해주세요.',
            remainingAttempts: remainingAttempts,
          );
        }

        if (error == 'INVALID_CREDENTIALS') {
          // 잘못된 이메일/비밀번호일 때는 명세서 메시지를 정확히 노출
          // remainingAttempts가 있으면 메시지에 포함
          String errorMessage = message?.isNotEmpty == true
              ? message!
              : '이메일 또는 비밀번호가 올바르지 않습니다.';

          if (remainingAttempts != null && remainingAttempts > 0) {
            errorMessage += ' (남은 시도 횟수: $remainingAttempts)';
          }

          throw Exception(errorMessage);
        }

        // 기타 401 오류는 백엔드 메시지 우선, 없으면 일반 메시지
        if (message != null && message.isNotEmpty) {
          throw Exception(message);
        }
        throw Exception('인증에 실패했습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 423) {
        // 계정 잠금 (423 Locked)
        final raw = response.body.isNotEmpty
            ? utf8.decode(response.bodyBytes)
            : '';
        Map<String, dynamic>? data;
        try {
          data = raw.isNotEmpty
              ? jsonDecode(raw) as Map<String, dynamic>
              : null;
        } catch (_) {
          data = null;
        }
        final message = data?['message'] as String?;
        final remainingAttempts = data?['remainingAttempts'] as int?;
        final needPasswordReset = data?['needPasswordReset'] as bool? ?? false;

        throw AccountLockedException(
          message: message?.isNotEmpty == true
              ? message!
              : '비밀번호를 여러 번 틀려 계정이 잠겼습니다. 비밀번호를 재설정해주세요.',
          remainingAttempts: remainingAttempts,
          email: email,
        );
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? '잘못된 요청입니다.');
      } else {
        print('🔴 [LOGIN] 실패 - 상태 코드: ${response.statusCode}');
        print('🔴 [LOGIN] 응답 본문: ${response.body}');
        throw Exception('로그인 실패 (${response.statusCode})');
      }
    } catch (e, stackTrace) {
      print('❌ [LOGIN] 에러 발생: $e');
      print('❌ [LOGIN] 스택 트레이스: $stackTrace');

      // 이미 Exception으로 throw된 경우 (401, 400 등)는 그대로 다시 throw
      if (e is Exception) {
        final errorStr = e.toString();
        // 백엔드에서 보낸 구체적인 에러 메시지는 그대로 전달
        if (errorStr.startsWith('Exception: ')) {
          final message = errorStr.substring('Exception: '.length);
          // 네트워크 관련 에러가 아닌 경우 (이메일/비밀번호 오류 등)는 그대로 전달
          if (!message.contains('SocketException') &&
              !message.contains('Failed host lookup') &&
              !message.contains('Connection refused') &&
              !message.contains('Network is unreachable') &&
              !message.contains('HandshakeException') &&
              !message.contains('Certificate') &&
              !message.contains('TimeoutException')) {
            throw e; // 원본 Exception 그대로 다시 throw
          }
        }
      }

      // 실제 네트워크 오류만 처리
      final errorStr = e.toString();
      if (errorStr.contains('SocketException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('Connection refused') ||
          errorStr.contains('Network is unreachable')) {
        throw Exception('서버에 연결할 수 없습니다. 인터넷 연결을 확인해주세요.');
      } else if (errorStr.contains('HandshakeException') ||
          errorStr.contains('Certificate')) {
        throw Exception('SSL 인증서 오류가 발생했습니다.');
      } else if (errorStr.contains('TimeoutException')) {
        throw Exception('요청 시간이 초과되었습니다.');
      }
      // 그 외의 경우는 원본 에러를 그대로 전달
      throw e;
    }
  }

  /// 회원가입 요청 (multipart/form-data 방식 - 이미지 파일 포함)
  /// 백엔드 명세: POST /api/users/signup (multipart/form-data)
  /// 응답: SignUpResponse { userId, email, nickname, profileImageUrl, createdAt }
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String nickname,
    File? imageFile,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      // 간단한 중복 이메일/유효성 모의 검증
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        throw Exception('올바른 이메일 형식을 입력해주세요');
      }
      if (password.length < 8 ||
          !RegExp(r'[A-Za-z]').hasMatch(password) ||
          !RegExp(r'\d').hasMatch(password) ||
          !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
        throw Exception('비밀번호는 영문, 숫자, 특수문자를 포함해 8자 이상이어야 합니다.');
      }
      if (nickname.trim().isEmpty) {
        throw Exception('닉네임을 입력해주세요');
      }
      // 중복 이메일 더미 체크
      if (email.toLowerCase() == 'exists@example.com') {
        throw Exception('이미 존재하는 이메일입니다.');
      }
      // API 명세서: { userId, email, nickname, profileImageUrl, createdAt }
      return {
        'userId': 1,
        'email': email,
        'nickname': nickname,
        'profileImageUrl': imageFile != null ? imageFile.path : '',
        'createdAt': DateTime.now().toIso8601String(),
      };
    }
    try {
      final uri = ApiClient.uri('/api/users/signup');
      final request = http.MultipartRequest('POST', uri);

      // 필수 필드 추가
      request.fields['email'] = email;
      request.fields['password'] = password;
      request.fields['nickname'] = nickname;

      // 이미지 파일이 있으면 추가
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        // API 명세서: { userId, email, nickname, profileImageUrl, createdAt }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'userId': (data['userId'] as num?)?.toInt(),
          'email': data['email'] as String? ?? '',
          'nickname': data['nickname'] as String? ?? '',
          'profileImageUrl': data['profileImageUrl'] as String? ?? '',
          'createdAt':
          data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        };
      } else if (response.statusCode == 409) {
        final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final error = data['error'] as String?;
        final message = data['message'] as String?;
        if (error == 'EMAIL_ALREADY_EXISTS') {
          throw Exception(message ?? '이미 존재하는 이메일입니다.');
        } else if (error == 'NICKNAME_ALREADY_EXISTS') {
          throw Exception(message ?? '이미 사용 중인 닉네임입니다.');
        }
        throw Exception(message ?? '이미 존재하는 이메일입니다.');
      } else if (response.statusCode == 400) {
        final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final error = data['error'] as String?;
        final message = data['message'] as String?;
        if (error == 'INVALID_REQUEST') {
          throw Exception(message ?? '잘못된 요청입니다.');
        } else if (error == 'EMAIL_NOT_VERIFIED') {
          throw Exception(message ?? '이메일 인증을 완료해주세요.');
        }
        throw Exception(message ?? '잘못된 요청입니다.');
      } else {
        throw Exception('회원가입 실패 (${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
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
  /// API 명세서: GET /api/users/me
  /// 응답: { userId, email, nickname, profileImageUrl, createdAt }
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
        // API 명세서: error: "UNAUTHORIZED", message: "인증이 필요합니다. 토큰이 유효하지 않거나 만료되었습니다."
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        throw Exception(body['message'] ?? '인증이 필요합니다. 토큰이 유효하지 않거나 만료되었습니다.');
      } else {
        throw Exception('사용자 정보 조회 실패 (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 로그아웃 (JWT 토큰 무효화)
  /// API 명세서: POST /api/users/logout, body에 refreshToken 전송
  /// 응답: { message: "성공적으로 로그아웃되었습니다." }
  Future<bool> logout() async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      clearAccessToken();
      return true;
    }
    try {
      // API 명세서: 저장된 refreshToken을 body로 전송
      final savedRefreshToken = _refreshToken;
      if (savedRefreshToken == null) {
        // refreshToken이 없으면 accessToken만 제거하고 성공 처리
        clearAccessToken();
        return true;
      }

      final response = await ApiClient.post(
        '/api/users/logout',
        body: {'refreshToken': savedRefreshToken},
      );

      if (response.statusCode == 200) {
        clearAccessToken();
        return true;
      } else if (response.statusCode == 400) {
        // API 명세서: error: "INVALID_REFRESH_TOKEN", message: "이미 만료되었거나 존재하지 않는 리프레시 토큰입니다."
        final data = jsonDecode(response.body);
        final error = data['error'] as String?;
        throw Exception(
          data['message'] ??
              (error == 'INVALID_REFRESH_TOKEN'
                  ? '이미 만료되었거나 존재하지 않는 리프레시 토큰입니다.'
                  : '리프레시 토큰이 유효하지 않습니다.'),
        );
      } else if (response.statusCode == 401) {
        // API 명세서: error: "UNAUTHORIZED", message: "로그인이 필요합니다."
        final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        throw Exception(data['message'] ?? '로그인이 필요합니다.');
      } else {
        final message = response.body.isNotEmpty
            ? jsonDecode(response.body)['message']
            : null;
        throw Exception(message ?? '로그아웃 실패 (${response.statusCode})');
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
        throw Exception('로그인이 필요합니다.');
      } else if (response.statusCode == 403) {
        // API 명세서: 403 Forbidden - 비밀번호 불일치
        throw Exception('비밀번호가 틀렸습니다');
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? '잘못된 요청입니다.');
      } else if (response.statusCode == 410) {
        // API 명세서: 410 Gone - 이미 탈퇴된 사용자
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? '이미 탈퇴 처리된 사용자입니다.');
      } else if (response.statusCode == 409) {
        // 데이터베이스 제약 조건 위반 (CONSTRAINT_VIOLATION)
        try {
          final data = response.body.isNotEmpty
              ? jsonDecode(response.body)
              : {};
          final message = data['message'] as String?;
          final code = data['code'] as String?;

          if (code == 'CONSTRAINT_VIOLATION' ||
              (message != null && message.contains('중복 데이터'))) {
            throw Exception('회원탈퇴할 수 없습니다. 연결된 데이터(사진, 앨범 등)가 있어 삭제할 수 없습니다.');
          }

          throw Exception(message ?? '회원탈퇴 중 충돌이 발생했습니다.');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('회원탈퇴 중 충돌이 발생했습니다.');
        }
      } else {
        throw Exception('회원탈퇴 실패 (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 사용자 정보 수정 (JSON 방식)
  /// API 명세서: PUT /api/users/me (JSON)
  /// 요청: { nickname?, profileImageUrl? } - 둘 중 하나 이상은 반드시 포함되어야 함
  /// 응답: { userId, email, nickname, profileImageUrl, updatedAt }
  Future<Map<String, dynamic>> updateProfile({
    String? nickname,
    String? profileImageUrl,
  }) async {
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
        'nickname': nickname ?? '네컷러버',
        'profileImageUrl': profileImageUrl ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      };
    }
    try {
      // API 명세서: 둘 중 하나 이상은 반드시 포함되어야 함
      final body = <String, dynamic>{};
      if (nickname != null && nickname.isNotEmpty) {
        body['nickname'] = nickname;
      }
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        body['profileImageUrl'] = profileImageUrl;
      }

      // 명세서 요구사항: 수정할 항목이 없으면 에러
      if (body.isEmpty) {
        throw Exception('수정할 항목이 없습니다.');
      }

      final response = await ApiClient.put('/api/users/me', body: body);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('인증이 필요합니다.');
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? '잘못된 요청입니다.');
      } else {
        throw Exception('사용자 정보 수정 실패 (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 사용자 정보 수정 (multipart/form-data 방식 - 이미지 파일 포함)
  /// 백엔드 명세: PUT /api/users/me (multipart/form-data)
  /// 응답: UserProfileResponse { userId, email, nickname, profileImageUrl, updatedAt }
  Future<Map<String, dynamic>> updateProfileWithImage({
    String? nickname,
    File? imageFile,
  }) async {
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
        'nickname': nickname ?? '네컷러버',
        'profileImageUrl': imageFile != null ? imageFile.path : '',
        'updatedAt': DateTime.now().toIso8601String(),
      };
    }
    try {
      final uri = ApiClient.uri('/api/users/me');
      final request = http.MultipartRequest('PUT', uri);

      // Authorization 헤더 추가
      if (_accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }

      // nickname이 있으면 추가
      if (nickname != null && nickname.isNotEmpty) {
        request.fields['nickname'] = nickname;
      }

      // 이미지 파일이 있으면 추가
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('인증이 필요합니다.');
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? '잘못된 요청입니다.');
      } else {
        throw Exception('사용자 정보 수정 실패 (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 프로필 이미지 업로드
  /// 백엔드 명세: POST /api/users/me/profile-image
  /// 응답: { profileImageUrl, message }
  Future<String> uploadProfileImage(File imageFile) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (_accessToken == null) {
        throw Exception('인증이 필요합니다.');
      }
      return imageFile.path;
    }
    try {
      final uri = ApiClient.uri('/api/users/me/profile-image');
      final request = http.MultipartRequest('POST', uri);

      // Authorization 헤더 추가
      if (_accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }

      // 이미지 파일 추가
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['profileImageUrl'] as String? ?? '';
      } else if (response.statusCode == 401) {
        throw Exception('인증이 필요합니다.');
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? '잘못된 요청입니다.');
      } else {
        throw Exception('프로필 이미지 업로드 실패 (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// JWT 액세스 토큰 재발급
  /// API 명세서: POST /api/auth/refresh, body에 refreshToken 전송
  /// 응답: { accessToken, expiresIn }
  Future<Map<String, dynamic>> refreshAccessToken() async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (_refreshToken == null) {
        throw Exception('리프레시 토큰이 유효하지 않거나 만료되었습니다.');
      }
      final newToken =
          'new_mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
      setAccessToken(newToken);
      return {'accessToken': newToken, 'expiresIn': 3600};
    }
    try {
      final savedRefreshToken = _refreshToken;
      if (savedRefreshToken == null) {
        throw Exception('리프레시 토큰이 없습니다.');
      }

      final response = await ApiClient.post(
        '/api/auth/refresh',
        body: {'refreshToken': savedRefreshToken},
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        // API 명세서: 응답 { accessToken, expiresIn }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['accessToken'] as String;
        final expiresIn = data['expiresIn'] as int? ?? 3600;
        setAccessToken(newAccessToken);
        // API 명세서: refreshToken은 선택적으로 갱신될 수 있음 (명세서에는 없지만 백엔드에서 제공 가능)
        final newRefreshToken = data['refreshToken'] as String?;
        if (newRefreshToken != null) {
          setRefreshToken(newRefreshToken);
        }
        // API 명세서 응답 형식: { accessToken, expiresIn }
        return {
          'accessToken': newAccessToken,
          'expiresIn': expiresIn,
          'refreshToken': newRefreshToken, // 선택적 (명세서에는 없지만 유지)
        };
      } else if (response.statusCode == 400) {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final error = body['error'] as String?;
        if (error == 'TOKEN_REQUIRED') {
          throw Exception(body['message'] ?? '리프레시 토큰이 필요합니다.');
        }
        throw Exception(body['message'] ?? '잘못된 요청입니다.');
      } else if (response.statusCode == 401) {
        // API 명세서: 401 에러 시 error: "INVALID_REFRESH_TOKEN"
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final error = body['error'] as String?;
        if (error == 'INVALID_REFRESH_TOKEN' || error == 'INVALID_TOKEN') {
          clearAccessToken(); // 토큰 제거
          throw Exception(body['message'] ?? '리프레시 토큰이 유효하지 않거나 만료되었습니다.');
        }
        clearAccessToken();
        throw Exception('리프레시 토큰이 유효하지 않거나 만료되었습니다.');
      } else {
        throw Exception('토큰 재발급 실패 (${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('리프레시 토큰') || e.toString().contains('TOKEN')) {
        rethrow;
      }
      throw Exception('네트워크 오류: $e');
    }
  }
  /// 카카오 로그인: 백엔드로 accessToken 전달
  Future<Map<String, dynamic>> loginWithKakao(String kakaoAccessToken) async {
    final response = await ApiClient.post(
      '/api/auth/oauth/kakao',
      body: {'accessToken': kakaoAccessToken},
      includeAuth: false,
    );

    return _handleSocialResponse(response, provider: '카카오');
  }
  /// 구글 로그인: 백엔드로 idToken 전달
  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await ApiClient.post(
      '/api/auth/oauth/google',
      body: {'idToken': idToken},
      includeAuth: false,
    );

    return _handleSocialResponse(response, provider: '구글');
  }

  /// 소셜 로그인 공통 응답 처리
  Future<Map<String, dynamic>> _handleSocialResponse(
      http.Response response, {
        required String provider,
      }) async {
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      final access = data['accessToken'] as String?;
      final refresh = data['refreshToken'] as String?;
      final user = data['user'] as Map<String, dynamic>?;

      final backendProvider = user?['provider'] as String?
          ?? (provider == '카카오'
              ? 'kakao'
              : provider == '구글'
              ? 'google'
              : 'social');

      if (access == null) {
        throw Exception('$provider 로그인 실패: accessToken 누락');
      }

      // 👇 newUser / isNewUser 둘 다 대응
      final isNewUser = (data['isNewUser'] ??
          data['newUser'] ??
          false) as bool;

      setAccessToken(access);
      if (refresh != null) {
        setRefreshToken(refresh);
      }

      final uid = user?['userId'] as int?;
      final nickname = user?['nickname'] as String?;
      final profileImageUrl = user?['profileImageUrl'] as String?;

      if (refresh != null && uid != null) {
        await AuthStorage.saveAuth(
          userId: uid,
          nickname: nickname ?? '',
          profileImageUrl: profileImageUrl,
          refreshToken: refresh,
          provider: backendProvider,
        );
      }

      return {
        'accessToken': access,
        'refreshToken': refresh,
        'userId': uid,
        'nickname': nickname,
        'profileImageUrl': profileImageUrl,
        'isNewUser': isNewUser,   // ✅ 이제 진짜 값 들어감
        'provider': backendProvider,
      };
    }

    final body = response.body.isNotEmpty ? response.body : '';
    throw Exception('$provider 로그인 실패: $body');
  }


  /// 소셜 로그인 (카카오/애플)
  /// API 명세서: POST /api/auth/login
  Future<Map<String, dynamic>> socialLogin({
    required String provider, // "KAKAO" or "APPLE"
    required String accessToken, // 소셜 플랫폼에서 발급받은 access token
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (provider != 'KAKAO' && provider != 'APPLE') {
        throw Exception('지원하지 않는 로그인 방식입니다.');
      }
      if (accessToken.isEmpty) {
        throw Exception('소셜 인증이 유효하지 않습니다.');
      }
      final mockToken =
          'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
      final mockRefreshToken =
          'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';
      setAccessToken(mockToken);
      setRefreshToken(mockRefreshToken);
      return {
        'accessToken': mockToken,
        'refreshToken': mockRefreshToken,
        'user': {
          'userId': 12,
          'nickname': '한욱',
          'profileImageUrl': 'https://cdn.nemo.app/profiles/12.jpg',
          'isNew': false,
        },
      };
    }
    try {
      final response = await ApiClient.post(
        '/api/auth/login',
        body: {'provider': provider, 'accessToken': accessToken},
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['accessToken'] as String;
        final refresh = data['refreshToken'] as String?;
        final user = data['user'] as Map<String, dynamic>?;

        setAccessToken(access);
        if (refresh != null) {
          setRefreshToken(refresh);
        }

        return {
          'accessToken': access,
          'refreshToken': refresh,
          'user': user ?? {},
        };
      } else if (response.statusCode == 400) {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final error = body['error'] as String?;
        if (error == 'UNSUPPORTED_PROVIDER') {
          throw Exception(body['message'] ?? '지원하지 않는 로그인 방식입니다.');
        }
        if (error == 'INVALID_SOCIAL_TOKEN') {
          throw Exception(body['message'] ?? '소셜 인증이 유효하지 않습니다.');
        }
        throw Exception(body['message'] ?? '잘못된 요청입니다.');
      } else {
        throw Exception('소셜 로그인 실패 (${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('지원하지 않는') ||
          e.toString().contains('유효하지 않습니다')) {
        rethrow;
      }
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 이메일 인증 (코드 발송 및 검증)
  /// API 명세서: POST /api/auth/email/verify
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    String? code, // code가 있으면 검증, 없으면 발송
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (!email.contains('@')) {
        throw Exception('이메일 형식이 유효하지 않습니다.');
      }
      if (code == null) {
        // 코드 발송
        return {'message': '인증코드가 이메일로 발송되었습니다.'};
      } else {
        // 코드 검증
        if (code == '123456') {
          return {'verified': true, 'message': '이메일 인증이 완료되었습니다.'};
        } else {
          throw Exception('인증코드가 올바르지 않습니다.');
        }
      }
    }
    try {
      final body = <String, dynamic>{'email': email};
      if (code != null && code.isNotEmpty) {
        body['code'] = code;
      }

      final response = await ApiClient.post(
        '/api/auth/email/verify',
        body: body,
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 400) {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final error = body['error'] as String?;
        if (error == 'INVALID_EMAIL_FORMAT') {
          throw Exception(body['message'] ?? '이메일 형식이 유효하지 않습니다.');
        }
        if (error == 'CODE_MISMATCH') {
          throw Exception(body['message'] ?? '인증코드가 올바르지 않습니다.');
        }
        if (error == 'CODE_EXPIRED') {
          throw Exception(body['message'] ?? '인증코드가 만료되었습니다. 다시 요청해주세요.');
        }
        throw Exception(body['message'] ?? '잘못된 요청입니다.');
      } else {
        throw Exception('이메일 인증 실패 (${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('이메일') || e.toString().contains('인증코드')) {
        rethrow;
      }
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 비밀번호 분실 인증코드 발송
  /// API 명세서: POST /api/auth/password/code
  Future<String> sendPasswordResetCode(String email) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (!email.contains('@')) {
        throw Exception('이메일 형식이 올바르지 않습니다.');
      }
      return '입력하신 이메일로 인증코드를 전송했습니다. 5분 안에 입력해주세요.';
    }
    try {
      final response = await ApiClient.post(
        '/api/auth/password/code',
        body: {'email': email},
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['message'] as String? ??
            '입력하신 이메일로 인증코드를 전송했습니다. 5분 안에 입력해주세요.';
      } else if (response.statusCode == 400) {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final error = body['error'] as String?;
        if (error == 'INVALID_EMAIL_FORMAT') {
          throw Exception(body['message'] ?? '이메일 형식이 올바르지 않습니다.');
        }
        if (error == 'RATE_LIMITED') {
          throw Exception(body['message'] ?? '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
        }
        if (error == 'MAIL_SEND_FAILED') {
          throw Exception(body['message'] ?? '인증코드 메일을 보내지 못했습니다.');
        }
        throw Exception(body['message'] ?? '잘못된 요청입니다.');
      } else {
        throw Exception('인증코드 발송 실패 (${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('이메일') ||
          e.toString().contains('요청이 너무 많습니다')) {
        rethrow;
      }
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 비밀번호 분실 인증코드 검증 (토큰 발급)
  /// API 명세서: POST /api/auth/password/code/verify
  Future<Map<String, dynamic>> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (code == '123456') {
        return {
          'verified': true,
          'resetToken': 'rt_${DateTime.now().millisecondsSinceEpoch}',
          'expiresIn': 600,
        };
      } else if (code == 'expired') {
        throw Exception('인증코드가 만료되었습니다. 다시 요청해주세요.');
      } else {
        throw Exception('인증코드가 올바르지 않습니다.');
      }
    }
    try {
      final response = await ApiClient.post(
        '/api/auth/password/code/verify',
        body: {'email': email, 'code': code},
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 400) {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final error = body['error'] as String?;
        if (error == 'CODE_MISMATCH') {
          throw Exception(body['message'] ?? '인증코드가 올바르지 않습니다.');
        }
        if (error == 'CODE_EXPIRED') {
          throw Exception(body['message'] ?? '인증코드가 만료되었습니다. 다시 요청해주세요.');
        }
        if (error == 'ATTEMPTS_EXCEEDED') {
          throw Exception(body['message'] ?? '입력 시도 횟수를 초과했습니다. 코드를 다시 받으세요.');
        }
        throw Exception(body['message'] ?? '잘못된 요청입니다.');
      } else {
        throw Exception('인증코드 검증 실패 (${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('인증코드') || e.toString().contains('시도 횟수')) {
        rethrow;
      }
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 비밀번호 분실 새 비밀번호 설정
  /// API 명세서: POST /api/auth/password/reset
  Future<String> resetPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (newPassword != confirmPassword) {
        throw Exception('새 비밀번호와 확인 값이 일치하지 않습니다.');
      }
      if (resetToken.isEmpty) {
        throw Exception('토큰이 유효하지 않거나 이미 사용/만료되었습니다.');
      }
      // 비밀번호 정책 검증
      if (newPassword.length < 8 || newPassword.length > 64) {
        throw Exception('비밀번호는 8~64자, 영문/숫자/특수문자 중 2종 이상을 포함해야 합니다.');
      }
      return '비밀번호가 변경되었습니다. 새 비밀번호로 로그인해주세요.';
    }
    try {
      final response = await ApiClient.post(
        '/api/auth/password/reset',
        body: {
          'resetToken': resetToken,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['message'] as String? ?? '비밀번호가 변경되었습니다. 새 비밀번호로 로그인해주세요.';
      } else if (response.statusCode == 400) {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final error = body['error'] as String?;
        if (error == 'INVALID_RESET_TOKEN') {
          throw Exception(body['message'] ?? '토큰이 유효하지 않거나 이미 사용/만료되었습니다.');
        }
        if (error == 'PASSWORD_POLICY_VIOLATION') {
          throw Exception(
            body['message'] ?? '비밀번호는 8~64자, 영문/숫자/특수문자 중 2종 이상을 포함해야 합니다.',
          );
        }
        if (error == 'PASSWORD_CONFIRM_MISMATCH') {
          throw Exception(body['message'] ?? '새 비밀번호와 확인 값이 일치하지 않습니다.');
        }
        throw Exception(body['message'] ?? '잘못된 요청입니다.');
      } else {
        throw Exception('비밀번호 재설정 실패 (${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('토큰') || e.toString().contains('비밀번호')) {
        rethrow;
      }
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 로그인 상태 비밀번호 변경
  /// API 명세서: PUT /api/users/me/password
  /// 요청: { currentPassword, newPassword, confirmPassword }
  /// 응답: { message: "비밀번호가 성공적으로 변경되었습니다. 다시 로그인해주세요." }
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
        // API 명세서: 응답 { message }
        final body = jsonDecode(response.body);
        return (body is Map && body['message'] is String)
            ? body['message'] as String
            : '비밀번호가 성공적으로 변경되었습니다. 다시 로그인해주세요.';
      }
      if (response.statusCode == 401) {
        // API 명세서: error: "UNAUTHORIZED", message: "로그인이 필요합니다."
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        throw Exception(body['message'] ?? '로그인이 필요합니다.');
      }
      if (response.statusCode == 403) {
        // API 명세서: error: "INVALID_CURRENT_PASSWORD", message: "현재 비밀번호가 일치하지 않습니다."
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        throw Exception(body['message'] ?? '현재 비밀번호가 일치하지 않습니다.');
      }
      if (response.statusCode == 400) {
        // API 명세서: error: "PASSWORD_CONFIRM_MISMATCH" 또는 "PASSWORD_POLICY_VIOLATION"
        final body = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;
        final err = body is Map ? (body['error'] as String?) : null;
        if (err == 'PASSWORD_CONFIRM_MISMATCH') {
          throw Exception(body?['message'] ?? '새 비밀번호와 확인 값이 일치하지 않습니다.');
        }
        if (err == 'PASSWORD_POLICY_VIOLATION') {
          throw Exception(
            body?['message'] ?? '비밀번호는 8~64자, 영문/숫자/특수문자 중 2종 이상을 포함해야 합니다.',
          );
        }
        throw Exception(body?['message'] ?? '잘못된 요청입니다.');
      }
      throw Exception('비밀번호 변경 실패 (${response.statusCode})');
    } catch (e) {
      rethrow;
    }
  }
}