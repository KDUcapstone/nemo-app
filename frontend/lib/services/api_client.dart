import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  static Uri uri(String path, [Map<String, String>? query]) {
    // baseUrl 끝의 슬래시와 path 시작의 슬래시 처리
    final base = AuthService.baseUrl.endsWith('/')
        ? AuthService.baseUrl.substring(0, AuthService.baseUrl.length - 1)
        : AuthService.baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$base$cleanPath';

    print('🔗 [ApiClient] baseUrl: ${AuthService.baseUrl}');
    print('🔗 [ApiClient] path: $path');
    print('🔗 [ApiClient] 최종 URL: $fullUrl');

    return Uri.parse(fullUrl).replace(queryParameters: query);
  }

  static Map<String, String> headers({
    bool includeAuth = true,
    bool json = true,
  }) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (includeAuth && AuthService.accessToken != null) {
      h['Authorization'] = 'Bearer ${AuthService.accessToken}';
    }
    return h;
  }

  static Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
    bool includeAuth = true,
  }) {
    return http.get(
      uri(path, queryParameters),
      headers: headers(includeAuth: includeAuth),
    );
  }

  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = uri(path);
    print('🌐 [ApiClient] POST 요청 URL: $url');
    print('🌐 [ApiClient] Headers: ${headers(includeAuth: includeAuth)}');
    print('🌐 [ApiClient] Body: ${body != null ? jsonEncode(body) : null}');

    try {
      final response = await http.post(
        url,
        headers: headers(includeAuth: includeAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      print('📡 [ApiClient] 응답 상태: ${response.statusCode}');
      print('📡 [ApiClient] 응답 본문: ${response.body}');
      return response;
    } catch (error) {
      print('❌ [ApiClient] 요청 실패: $error');
      rethrow;
    }
  }

  static Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) {
    return http.put(
      uri(path),
      headers: headers(includeAuth: includeAuth),
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
