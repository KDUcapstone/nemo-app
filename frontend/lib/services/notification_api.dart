import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/models/notification_models.dart';
import 'package:frontend/app/constants.dart';
import 'package:frontend/services/friend_api.dart';
import 'package:frontend/services/album_api.dart';

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
                'inviteRole': 'EDITOR',
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

  // PATCH /api/notifications/{notificationId}/read - 알림 단건 읽음 처리
  // API 명세서: 응답에 notificationId, isRead 포함
  Future<Map<String, dynamic>> markRead(int notificationId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'notificationId': notificationId,
        'isRead': true,
      };
    }
    final res = await http.patch(
      _uri('/api/notifications/$notificationId/read'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      // API 명세서: { notificationId, isRead }
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 403) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      throw Exception(body['message'] ?? '해당 알림에 대한 권한이 없습니다.');
    }
    if (res.statusCode == 404) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      final error = body['error'] as String?;
      if (error == 'NOTIFICATION_NOT_FOUND') {
        throw Exception(body['message'] ?? '요청한 알림이 존재하지 않습니다.');
      }
      throw Exception(body['message'] ?? '요청한 알림이 존재하지 않습니다.');
    }
    throw Exception('알림 읽음 처리 실패 (${res.statusCode})');
  }

  // PATCH /api/notifications/read-all - 전체 알림 읽음 처리
  // API 명세서: 응답에 updatedCount, unreadCount 포함
  Future<Map<String, dynamic>> markAllRead() async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'updatedCount': 4,
        'unreadCount': 0,
      };
    }
    final res = await http.patch(
      _uri('/api/notifications/read-all'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      // API 명세서: { updatedCount, unreadCount }
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 401) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      throw Exception(body['message'] ?? '로그인이 필요합니다.');
    }
    throw Exception('전체 읽음 처리 실패 (${res.statusCode})');
  }

  // Mock only actions for friend request and album invite
  Future<void> friendRequestAction({
    int? requestId,
    int? requesterUserId,
    required bool accept,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    // Prefer requestId per spec; fallback to requesterUserId path only if provided (legacy)
    if (requestId != null && requestId > 0) {
      if (accept) {
        await FriendApi.acceptRequest(requestId);
      } else {
        await FriendApi.rejectRequest(requestId);
      }
      return;
    }
    // Legacy fallback (if only requesterUserId is present and backend supports it)
    if (requesterUserId != null && requesterUserId > 0 && accept) {
      await FriendApi.acceptFriend(requesterUserId);
      return;
    }
  }

  Future<void> albumInviteAction(int albumId, {required bool accept}) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    if (accept) {
      await AlbumApi.acceptShare(albumId);
    } else {
      await AlbumApi.rejectShare(albumId);
    }
  }
}


