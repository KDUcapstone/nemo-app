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
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      if (decoded is Map<String, dynamic>) {
        final List list = decoded['content'] ?? decoded['friends'] ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return const <Map<String, dynamic>>[];
    }
    throw Exception('Failed to fetch friends (${res.statusCode})');
  }

  // GET /api/friends/search?keyword=
  static Future<List<Map<String, dynamic>>> search(String keyword) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (keyword.trim().isEmpty) return [];
      final data = [
        {
          'userId': 2,
          'nickname': '네컷매니아',
          'email': 'fourcut@example.com',
          'profileImageUrl': 'https://picsum.photos/seed/user2/200/200',
          'isFriend': true,
        },
        {
          'userId': 3,
          'nickname': '네컷러버',
          'email': 'lover@nemo.com',
          'profileImageUrl': 'https://picsum.photos/seed/user3/200/200',
          'isFriend': false,
        },
      ];
      final q = keyword.toLowerCase();
      return data
          .where(
            (e) =>
                (e['nickname'] as String).toLowerCase().contains(q) ||
                (e['email'] as String).toLowerCase().contains(q),
          )
          .toList();
    }
    final uri = _uri(
      '/api/friends/search',
    ).replace(queryParameters: {'keyword': keyword});
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    if (res.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    }
    throw Exception('Failed to search friends (${res.statusCode})');
  }

  // POST /api/friends { targetUserId }
  static Future<Map<String, dynamic>> addFriend(int targetUserId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (targetUserId <= 0) {
        throw Exception('USER_NOT_FOUND');
      }
      // 더미: 이미 친구인 경우
      if (targetUserId == 2) {
        throw Exception('ALREADY_FRIEND');
      }
      return {
        'message': '친구 요청이 완료되었습니다.',
        'friend': {
          'userId': targetUserId,
          'nickname': '친구$targetUserId',
          'profileImageUrl': null,
        },
      };
    }
    final res = await http.post(
      _uri('/api/friends'),
      headers: _headers(),
      body: jsonEncode({'targetUserId': targetUserId}),
    );
    if (res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 409) throw Exception('ALREADY_FRIEND');
    if (res.statusCode == 404) throw Exception('USER_NOT_FOUND');
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    throw Exception('Failed to add friend (${res.statusCode})');
  }

  // GET /api/friends → friends array
  static Future<List<Map<String, dynamic>>> getFriends() async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return [
        {
          'userId': 3,
          'nickname': '네컷러버',
          'email': 'friend1@example.com',
          'profileImageUrl': 'https://picsum.photos/seed/user3/200/200',
          'addedAt': DateTime.now().toIso8601String(),
        },
        {
          'userId': 5,
          'nickname': '사진장인',
          'email': 'friend2@nemo.com',
          'profileImageUrl': null,
          'addedAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
      ];
    }
    final res = await http.get(_uri('/api/friends'), headers: _headers());
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      return const <Map<String, dynamic>>[];
    }
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    throw Exception('Failed to fetch friends (${res.statusCode})');
  }

  // DELETE /api/friends/{friendId}
  static Future<Map<String, dynamic>> deleteFriend(int friendUserId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (friendUserId <= 0) throw Exception('USER_NOT_FOUND');
      return {'message': '친구가 성공적으로 삭제되었습니다.', 'deletedFriendId': friendUserId};
    }
    final res = await http.delete(
      _uri('/api/friends/$friendUserId'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body;
    }
    if (res.statusCode == 204) {
      return {'message': '친구가 성공적으로 삭제되었습니다.', 'deletedFriendId': friendUserId};
    }
    if (res.statusCode == 400) throw Exception('NOT_A_FRIEND');
    if (res.statusCode == 404) throw Exception('USER_NOT_FOUND');
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    throw Exception('Failed to delete friend (${res.statusCode})');
  }
}
