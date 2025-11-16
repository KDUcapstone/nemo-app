import 'dart:convert';

enum NotificationType {
  FRIEND_REQUEST,
  FRIEND_ACCEPTED,
  ALBUM_INVITE,
  ALBUM_NEW_PHOTO,
  PHOTO_TAGGED,
}

enum TargetType { USER, PHOTO, ALBUM }

enum ActionType { OPEN_FRIEND_REQUEST, OPEN_PHOTO, OPEN_ALBUM }

class Actor {
  final int userId;
  final String nickname;
  final String? profileImageUrl;
  const Actor({required this.userId, required this.nickname, this.profileImageUrl});
  factory Actor.fromJson(Map<String, dynamic> j) => Actor(
        userId: j['userId'] as int,
        nickname: j['nickname']?.toString() ?? '',
        profileImageUrl: j['profileImageUrl'] as String?,
      );
}

class TargetRef {
  final TargetType type;
  final int id;
  const TargetRef({required this.type, required this.id});
  factory TargetRef.fromJson(Map<String, dynamic> j) => TargetRef(
        type: TargetType.values.firstWhere((e) => e.name == j['type']),
        id: (j['id'] as num).toInt(),
      );
}

class NotificationItem {
  final int notificationId;
  final NotificationType type;
  final String message;
  final DateTime createdAt;
  bool isRead;
  final Actor? actor;
  final TargetRef? target;
  final ActionType? actionType;

  NotificationItem({
    required this.notificationId,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.actor,
    this.target,
    this.actionType,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        notificationId: (j['notificationId'] as num).toInt(),
        type: NotificationType.values.firstWhere((e) => e.name == j['type']),
        message: j['message']?.toString() ?? '',
        createdAt: DateTime.parse(j['createdAt'].toString()),
        isRead: j['isRead'] == true,
        actor: j['actor'] == null ? null : Actor.fromJson((j['actor'] as Map).cast<String, dynamic>()),
        target: j['target'] == null ? null : TargetRef.fromJson((j['target'] as Map).cast<String, dynamic>()),
        actionType: j['actionType'] == null
            ? null
            : ActionType.values.firstWhere((e) => e.name == j['actionType']),
      );
}

class NotificationGroup {
  final String label; // "오늘", "최근 7일"
  final List<NotificationItem> items;
  const NotificationGroup({required this.label, required this.items});
  factory NotificationGroup.fromJson(Map<String, dynamic> j) => NotificationGroup(
        label: j['label']?.toString() ?? '',
        items: ((j['items'] as List?) ?? const [])
            .map((e) => NotificationItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class PageInfo {
  final int size;
  final int totalElements;
  final int totalPages;
  final int number;
  const PageInfo({
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.number,
  });
  factory PageInfo.fromJson(Map<String, dynamic> j) => PageInfo(
        size: (j['size'] as num).toInt(),
        totalElements: (j['totalElements'] as num).toInt(),
        totalPages: (j['totalPages'] as num).toInt(),
        number: (j['number'] as num).toInt(),
      );
}

class NotificationsResponse {
  final int unreadCount;
  final List<NotificationGroup> groups;
  final PageInfo page;
  const NotificationsResponse({
    required this.unreadCount,
    required this.groups,
    required this.page,
  });
  factory NotificationsResponse.fromJson(Map<String, dynamic> j) => NotificationsResponse(
        unreadCount: (j['summary']?['unreadCount'] as num?)?.toInt() ?? 0,
        groups: ((j['groups'] as List?) ?? const [])
            .map((e) => NotificationGroup.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        page: PageInfo.fromJson((j['page'] as Map).cast<String, dynamic>()),
      );

  static NotificationsResponse decodeBody(String body) {
    final m = jsonDecode(body) as Map<String, dynamic>;
    return NotificationsResponse.fromJson(m);
  }
}


