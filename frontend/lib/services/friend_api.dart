import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/app/constants.dart';
import 'package:frontend/services/auth_service.dart';

class FriendApi {
  static Uri _uri(String path) {
    // baseUrl 끝의 슬래시와 path 시작의 슬래시 처리
    final base = AuthService.baseUrl.endsWith('/')
        ? AuthService.baseUrl.substring(0, AuthService.baseUrl.length - 1)
        : AuthService.baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$cleanPath');
  }

  static Map<String, String> _headers() {
    final token = AuthService.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET /api/friends
  // ⚠️ 레거시: search 파라미터 지원 (명세서에는 없음)
  // 명세서 기준으로는 GET /api/friends/search?keyword= (search 메서드)를 사용해야 함
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
          'profileImageUrl': null,
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
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
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
          'nickname': '네컷러버',
          'email': 'fourcut@example.com',
          'profileImageUrl': 'https://picsum.photos/seed/user2/200/200',
          'isFriend': true,
        },
        {
          'userId': 3,
          'nickname': '사진장인',
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

  // ✅ POST /api/friends?targetId= (백엔드 @RequestParam Long targetId 에 맞춤)
  static Future<Map<String, dynamic>> addFriend(int targetUserId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (targetUserId <= 0) throw Exception('USER_NOT_FOUND');
      if (targetUserId == 2) throw Exception('ALREADY_FRIEND');
      return {
        'requestId': 12,
        'status': 'PENDING',
        'message': '친구 요청이 전송되었습니다.',
        'target': {
          'userId': targetUserId,
          'nickname': '네컷러버',
          'profileImageUrl':
              'https://picsum.photos/seed/user$targetUserId/200/200',
        },
      };
    }

    // 명세: POST /api/friends with JSON body { targetUserId }
    final res = await http.post(
      _uri('/api/friends'),
      headers: _headers(),
      body: jsonEncode({'targetUserId': targetUserId}),
    );

    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 409) {
      final body = jsonDecode(res.body);
      final err = (body is Map && body['error'] is String)
          ? body['error'] as String
          : '';
      if (err == 'ALREADY_FRIEND' || err == 'REQUEST_ALREADY_EXISTS') {
        throw Exception(err);
      }
      throw Exception('CONFLICT');
    }
    if (res.statusCode == 404) throw Exception('USER_NOT_FOUND');
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 400) {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] == 'CANNOT_ADD_SELF') {
        throw Exception('CANNOT_ADD_SELF');
      }
      throw Exception('BAD_REQUEST');
    }
    throw Exception('Failed to add friend (${res.statusCode})');
  }

  // ⚠️ 레거시 메서드: 명세서에는 없지만 일부 코드에서 사용 중
  // 명세서 기준으로는 POST /api/friends/{requestId}/accept (acceptRequest)를 사용해야 함
  // PUT /api/friends/accept?requesterId= (백엔드 @RequestParam Long requesterId 에 맞춤)
  static Future<Map<String, dynamic>> acceptFriend(int requesterUserId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (requesterUserId <= 0) throw Exception('USER_NOT_FOUND');
      return {
        'message': '친구 요청을 수락했습니다.',
        'friend': {
          'userId': requesterUserId,
          'nickname': '친구$requesterUserId',
          'email': 'friend$requesterUserId@example.com',
          'profileImageUrl': null,
          'addedAt': DateTime.now().toIso8601String(),
        },
      };
    }

    final uri = _uri(
      '/api/friends/accept',
    ).replace(queryParameters: {'requesterId': requesterUserId.toString()});

    // 🔹 body 제거 (쿼리 파라미터만 전달)
    final res = await http.put(uri, headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 404) throw Exception('USER_NOT_FOUND');
    if (res.statusCode == 409) throw Exception('ALREADY_FRIEND');
    throw Exception('Failed to accept friend (${res.statusCode})');
  }

  // GET /api/friends?status=PENDING (가정) → 받은 요청 목록
  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return [
        {
          'requestId': 12,
          'userId': 7,
          'nickname': '신규친구7',
          'email': 'new7@example.com',
          'profileImageUrl': null,
          'requestedAt': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
        },
        {
          'requestId': 15,
          'userId': 8,
          'nickname': '신규친구8',
          'email': 'new8@example.com',
          'profileImageUrl': null,
          'requestedAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
      ];
    }
    // 명세: GET /api/friends/requests
    final res = await http.get(
      _uri('/api/friends/requests'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    throw Exception('Failed to fetch requests (${res.statusCode})');
  }

  // POST /api/friends/{requestId}/accept
  // API 명세서: 응답에 requestId, friendUserId, nickname, message 포함
  static Future<Map<String, dynamic>> acceptRequest(int requestId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'requestId': requestId,
        'friendUserId': 4,
        'nickname': '포토러버',
        'message': '친구 요청이 성공적으로 수락되었습니다.',
      };
    }
    final res = await http.post(
      _uri('/api/friends/$requestId/accept'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 404) throw Exception('REQUEST_NOT_FOUND');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode == 400) {
      final body = jsonDecode(res.body);
      final error = body is Map ? (body['error'] as String?) : null;
      if (error == 'ALREADY_PROCESSED') throw Exception('ALREADY_PROCESSED');
      throw Exception('BAD_REQUEST');
    }
    throw Exception('Failed to accept request (${res.statusCode})');
  }

  // POST /api/friends/{requestId}/reject
  // API 명세서: 응답에 requestId, message 포함
  static Future<Map<String, dynamic>> rejectRequest(int requestId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {'requestId': requestId, 'message': '친구 요청이 거절되었습니다.'};
    }
    final res = await http.post(
      _uri('/api/friends/$requestId/reject'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 404) throw Exception('REQUEST_NOT_FOUND');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    throw Exception('Failed to reject request (${res.statusCode})');
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
          'nickname': '사진장인',
          'email': 'friend1@example.com',
          'profileImageUrl': 'https://picsum.photos/seed/user3/200/200',
          'addedAt': DateTime.now().toIso8601String(),
        },
        {
          'userId': 5,
          'nickname': '네컷러버',
          'email': 'friend2@nemo.com',
          'profileImageUrl': null,
          'addedAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
      ];
    }
    final uri = _uri('/api/friends');
    print('👥 [FriendApi] getFriends 요청 URL: $uri');
    print('👥 [FriendApi] 헤더: ${_headers()}');

    final res = await http.get(uri, headers: _headers());

    print('👥 [FriendApi] 응답 상태: ${res.statusCode}');
    print('👥 [FriendApi] 응답 본문: ${res.body}');

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      return const <Map<String, dynamic>>[];
    }
    if (res.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    }
    if (res.statusCode == 400) {
      // 400 에러의 경우 상세 메시지 확인
      final errorBody = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      final message = errorBody['message'] as String?;
      final error = errorBody['error'] as String?;
      print(
        '🔴 [FriendApi] 400 에러 상세: message=$message, error=$error, body=$errorBody',
      );
      throw Exception(message ?? error ?? '잘못된 요청입니다. (400)');
    }
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
