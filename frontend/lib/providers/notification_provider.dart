import 'package:flutter/material.dart';
import 'package:frontend/models/notification_models.dart';
import 'package:frontend/services/notification_api.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationApi _api = NotificationApi();

  bool _loading = false;
  String? _error;
  bool _onlyUnread = false;
  int _page = 0;
  final int _size = 20;
  bool _hasMore = true;

  int _unreadCount = 0;
  final List<NotificationGroup> _groups = [];

  bool get loading => _loading;
  String? get error => _error;
  bool get onlyUnread => _onlyUnread;
  bool get hasMore => _hasMore;
  int get unreadCount => _unreadCount;
  List<NotificationGroup> get groups => List.unmodifiable(_groups);

  Future<void> refresh() async {
    if (_loading) return;
    _setLoading(true);
    try {
      _page = 0;
      _groups.clear();
      final res = await _api.list(
        onlyUnread: _onlyUnread,
        page: _page,
        size: _size,
      );
      _unreadCount = res.unreadCount;
      _hasMore = res.page.number + 1 < res.page.totalPages;
      _groups.addAll(res.groups);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _setLoading(true);
    try {
      _page += 1;
      final res = await _api.list(
        onlyUnread: _onlyUnread,
        page: _page,
        size: _size,
      );
      _hasMore = res.page.number + 1 < res.page.totalPages;
      _mergeGroups(res.groups);
      _error = null;
    } catch (e) {
      _page -= 1;
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setOnlyUnread(bool value) async {
    _onlyUnread = value;
    await refresh();
  }

  Future<void> markRead(NotificationItem item) async {
    if (item.isRead) return;
    final prevUnread = _unreadCount;
    // 낙관적
    _setItemRead(item.notificationId, true);
    _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
    notifyListeners();
    try {
      await _api.markRead(item.notificationId);
    } catch (e) {
      // 롤백
      _setItemRead(item.notificationId, false);
      _unreadCount = prevUnread;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    if (_unreadCount == 0) return;
    final prevGroupsSnapshot = _snapshotGroups();
    final prevUnread = _unreadCount;
    // 낙관적
    _setAllRead(true);
    _unreadCount = 0;
    notifyListeners();
    try {
      await _api.markAllRead();
    } catch (e) {
      // 롤백
      _restoreGroups(prevGroupsSnapshot);
      _unreadCount = prevUnread;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> actOnFriendRequest(NotificationItem item, {required bool accept}) async {
    // 낙관적: 읽음 처리 + 토스트는 호출측
    await markRead(item);
    try {
      await _api.friendRequestAction(item.actor?.userId ?? 0, accept: accept);
      _removeItem(item.notificationId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> actOnAlbumInvite(NotificationItem item, {required bool accept}) async {
    await markRead(item);
    try {
      await _api.albumInviteAction(item.target?.id ?? 0, accept: accept);
      _removeItem(item.notificationId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void _removeItem(int notificationId) {
    for (var gi = 0; gi < _groups.length; gi++) {
      final g = _groups[gi];
      final beforeLen = g.items.length;
      g.items.removeWhere((it) => it.notificationId == notificationId);
      if (g.items.length != beforeLen) {
        // 빈 그룹은 유지 (서버 그룹 라벨 보존), 필요 시 제거 가능
        break;
      }
    }
  }

  void _mergeGroups(List<NotificationGroup> newGroups) {
    // 단순 append. 필요 시 label 기반 머지/정렬 추가 가능
    _groups.addAll(newGroups);
    notifyListeners();
  }

  void _setItemRead(int id, bool isRead) {
    for (var gi = 0; gi < _groups.length; gi++) {
      final g = _groups[gi];
      for (var ii = 0; ii < g.items.length; ii++) {
        final it = g.items[ii];
        if (it.notificationId == id) {
          it.isRead = isRead;
          return;
        }
      }
    }
  }

  void _setAllRead(bool isRead) {
    for (final g in _groups) {
      for (final it in g.items) {
        it.isRead = isRead;
      }
    }
  }

  List<NotificationGroup> _snapshotGroups() {
    return _groups
        .map(
          (g) => NotificationGroup(
            label: g.label,
            items: g.items
                .map((it) => NotificationItem(
                      notificationId: it.notificationId,
                      type: it.type,
                      message: it.message,
                      createdAt: it.createdAt,
                      isRead: it.isRead,
                      actor: it.actor,
                      target: it.target,
                      actionType: it.actionType,
                    ))
                .toList(),
          ),
        )
        .toList();
  }

  void _restoreGroups(List<NotificationGroup> snapshot) {
    _groups
      ..clear()
      ..addAll(snapshot);
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}


