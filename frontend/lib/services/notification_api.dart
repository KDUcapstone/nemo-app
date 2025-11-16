import 'package:http/http.dart' as http;
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/models/notification_models.dart';
import 'package:frontend/app/constants.dart';
import 'package:frontend/services/friend_api.dart';

class NotificationApi {
  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AuthService.baseUrl}$path').replace(
      queryParameters: query,
    );
  }

  static Map<String, String> _headers() {
    final token = AuthService.accessToken;
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<NotificationsResponse> list({
    bool onlyUnread = false,
    int page = 0,
    int size = 20,
  }) async {
    if (AppConstants.useMockApi) {
      // 모킹: 알림 2건
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      final mock = {
        'summary': {'unreadCount': 4},
        'groups': [
          {
            'label': '오늘',
            'items': [
              {
                'notificationId': 101,
                'type': 'FRIEND_REQUEST',
                'message': '다빈님이 회원님에게 친구 요청을 보냈어요.',
                'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
                'isRead': false,
                'actor': {
                  'userId': 2,
                  'nickname': '다빈',
                  'profileImageUrl': null,
                },
                'target': {'type': 'USER', 'id': 2},
                'actionType': 'OPEN_FRIEND_REQUEST',
              },
              {
                'notificationId': 98,
                'type': 'ALBUM_INVITE',
                'message': '민수님이 공유 앨범에 새로운 참여자를 초대했어요.',
                'createdAt': DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(),
                'isRead': false,
                'actor': {
                  'userId': 5,
                  'nickname': '민수',
                  'profileImageUrl': null,
                },
                'target': {'type': 'ALBUM', 'id': 777},
                'actionType': 'OPEN_ALBUM',
              },
              {
                'notificationId': 97,
                'type': 'ALBUM_NEW_PHOTO',
                'message': '공유 앨범에 친구가 새 사진을 추가했어요.',
                'createdAt': DateTime.now().subtract(const Duration(minutes: 35)).toIso8601String(),
                'isRead': false,
                'actor': {
                  'userId': 6,
                  'nickname': '지윤',
                  'profileImageUrl': null,
                },
                'target': {'type': 'ALBUM', 'id': 777},
                'actionType': 'OPEN_ALBUM',
              },
              {
                'notificationId': 95,
                'type': 'PHOTO_TAGGED',
                'message': '한일님이 회원님을 사진에 태그했어요.',
                'createdAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
                'isRead': false,
                'actor': {
                  'userId': 3,
                  'nickname': '한일',
                  'profileImageUrl': null,
                },
                'target': {'type': 'PHOTO', 'id': 3001},
                'actionType': 'OPEN_PHOTO',
              },
            ],
          }
        ],
        'page': {'size': size, 'totalElements': 4, 'totalPages': 1, 'number': page},
      };
      return NotificationsResponse.fromJson(mock);
    }
    final qp = <String, String>{
      'onlyUnread': onlyUnread.toString(),
      'page': page.toString(),
      'size': size.toString(),
    };
    final res = await http.get(_uri('/api/notifications', qp), headers: _headers());
    if (res.statusCode == 200) {
      return NotificationsResponse.decodeBody(res.body);
    }
    if (res.statusCode == 401) {
      throw Exception('로그인이 필요합니다. (401)');
    }
    if (res.statusCode == 400) {
      throw Exception('page 또는 size 값이 올바르지 않습니다. (400)');
    }
    throw Exception('알림 목록 조회 실패 (${res.statusCode})');
  }

  Future<void> markRead(int notificationId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return;
    }
    final res = await http.patch(
      _uri('/api/notifications/$notificationId/read'),
      headers: _headers(),
    );
    if (res.statusCode == 200) return;
    if (res.statusCode == 403) {
      throw Exception('해당 알림에 대한 권한이 없습니다. (403)');
    }
    if (res.statusCode == 404) {
      throw Exception('요청한 알림이 존재하지 않습니다. (404)');
    }
    throw Exception('알림 읽음 처리 실패 (${res.statusCode})');
  }

  Future<void> markAllRead() async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return;
    }
    final res = await http.patch(
      _uri('/api/notifications/read-all'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return;
    }
    if (res.statusCode == 401) {
      throw Exception('로그인이 필요합니다. (401)');
    }
    throw Exception('전체 읽음 처리 실패 (${res.statusCode})');
  }

  // Mock only actions for friend request and album invite
  Future<void> friendRequestAction(int requesterUserId, {required bool accept}) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    // accept: 실제 FriendApi 연동
    if (accept) {
      await FriendApi.acceptFriend(requesterUserId);
      return;
    }
    // decline: 백엔드 엔드포인트 미정 → 일단 무동작 (프론트 로컬 처리)
  }

  Future<void> albumInviteAction(int albumId, {required bool accept}) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    // 실서버 연동 시 PATCH /api/albums/{albumId}/invites:accept|decline 등으로 교체
    // 현재는 엔드포인트 미정 → 일단 성공으로 간주
  }
}


