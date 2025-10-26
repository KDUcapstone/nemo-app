import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/app/constants.dart';
import 'package:frontend/services/auth_service.dart';

class FriendApi {
  static Uri _uri(String path) => Uri.parse('${AuthService.baseUrl}$path');
  static Map<String, String> _headers() {
    final token = AuthService.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET /api/friends?search=
  static Future<List<Map<String, dynamic>>> list({String? search}) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      final all = List.generate(
        8,
        (i) => {
          'userId': i + 1,
          'nickname': '친구${i + 1}',
          'email': 'friend${i + 1}@example.com',
          'avatarUrl': null,
        },
      );
      if (search == null || search.trim().isEmpty) return all;
      final q = search.toLowerCase();
      return all
          .where(
            (e) =>
                (e['nickname'] as String).toLowerCase().contains(q) ||
                (e['email'] as String).toLowerCase().contains(q),
          )
          .toList();
    }
    final uri = _uri('/api/friends').replace(
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final List list = body['content'] ?? body['friends'] ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to fetch friends (${res.statusCode})');
  }
}
