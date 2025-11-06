import 'dart:math';
import 'package:frontend/app/constants.dart';

class FriendApi {
  // 간단 모킹 데이터 풀
  static final List<Map<String, dynamic>> _mockUsers = List.generate(12, (i) {
    return {
      'userId': i + 1,
      'nickname': 'friend_${i + 1}',
      'email': 'friend${i + 1}@example.com',
      'profileImageUrl': null,
    };
  });

  static final Set<int> _friendIds = {1, 2, 3};
  static final List<Map<String, dynamic>> _pending = List.generate(3, (i) {
    final id = 100 + i;
    return {
      'requestId': id,
      'requester': {
        'userId': id,
        'nickname': 'requester_$id',
        'email': 'requester$id@example.com',
        'profileImageUrl': null,
      },
      'status': 'PENDING',
    };
  });

  static Future<List<Map<String, dynamic>>> list() async {
    await Future<void>.delayed(
      Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
    );
    return _mockUsers
        .where((u) => _friendIds.contains(u['userId'] as int))
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> search(String q) async {
    await Future<void>.delayed(
      Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
    );
    final qq = q.trim().toLowerCase();
    if (qq.isEmpty) return _mockUsers.toList(growable: false);
    return _mockUsers
        .where((u) {
          final nick = (u['nickname'] as String?)?.toLowerCase() ?? '';
          final email = (u['email'] as String?)?.toLowerCase() ?? '';
          return nick.contains(qq) || email.contains(qq);
        })
        .toList(growable: false);
  }

  static Future<bool> addFriend(int userId) async {
    await Future<void>.delayed(
      Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
    );
    _friendIds.add(userId);
    return true;
  }

  static Future<bool> deleteFriend(int userId) async {
    await Future<void>.delayed(
      Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
    );
    _friendIds.remove(userId);
    return true;
  }

  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    await Future<void>.delayed(
      Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
    );
    return _pending.toList(growable: false);
  }

  static Future<bool> acceptFriend(int requesterUserId) async {
    await Future<void>.delayed(
      Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
    );
    _friendIds.add(requesterUserId);
    _pending.removeWhere((e) => (e['requester']?['userId'] == requesterUserId));
    return true;
  }

  // 편의: 더미 데이터 리셋
  static void resetMock() {
    _friendIds
      ..clear()
      ..addAll({1, 2, 3});
    _pending
      ..clear()
      ..addAll(List.generate(3, (i) {
        final id = 100 + i;
        return {
          'requestId': id,
          'requester': {
            'userId': id,
            'nickname': 'requester_$id',
            'email': 'requester$id@example.com',
            'profileImageUrl': null,
          },
          'status': 'PENDING',
        };
      }));
  }
}


