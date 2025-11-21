import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  static Uri uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AuthService.baseUrl}$path')
        .replace(queryParameters: query);
  }

  static Map<String, String> headers({bool includeAuth = true, bool json = true}) {
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
  }) {
    return http.post(
      uri(path),
      headers: headers(includeAuth: includeAuth),
      body: body != null ? jsonEncode(body) : null,
    );
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

  static Future<http.Response> patch(
    String path, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) {
    return http.patch(
      uri(path),
      headers: headers(includeAuth: includeAuth),
      body: body != null ? jsonEncode(body) : null,
    );
  }
}

