import 'package:flutter/material.dart';
import 'package:frontend/services/friend_api.dart';

class FriendsListScreen extends StatefulWidget {
  final int initialTabIndex;
  const FriendsListScreen({super.key, this.initialTabIndex = 0});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late final TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _friends = const [];
  List<Map<String, dynamic>> _results = const [];
  List<Map<String, dynamic>> _requests = const [];
  final Set<int> _dismissedRequestIds = {};
  final Set<int> _pendingRequestUserIds = {}; // 친구 요청을 보낸 사용자 ID 목록

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 2));
    _loadFriends();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    try {
      final list = await FriendApi.getFriends();
      setState(() => _friends = list);
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      final msg = errorStr.startsWith('Exception: ')
          ? errorStr.substring('Exception: '.length)
          : '친구 목록을 불러오지 못했습니다.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String keyword) async {
    setState(() => _loading = true);
    try {
      final list = await FriendApi.search(keyword);
      setState(() => _results = list);
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      final msg = errorStr.startsWith('Exception: ')
          ? errorStr.substring('Exception: '.length)
          : '검색에 실패했습니다.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRequests() async {
    try {
      final list = await FriendApi.getPendingRequests();
      if (!mounted) return;
      setState(() {
        _requests = list
            .where((e) => !_dismissedRequestIds.contains((e['requestId'] ?? -1) as int))
            .toList();
      });
    } catch (_) {
      // 요청이 없거나 API 미구현 시 조용히 무시
    }
  }

  Future<void> _delete(int userId, String nickname) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('친구 삭제'),
        content: Text('정말 ${nickname}님을 친구에서 삭제하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FriendApi.deleteFriend(userId);
      setState(() {
        _friends.removeWhere((e) => e['userId'] == userId);
        _results = _results
            .map((e) => e['userId'] == userId ? {...e, 'isFriend': false} : e)
            .toList();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('삭제: $nickname')));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('NOT_A_FRIEND')
          ? '친구 목록에 없는 사용자입니다.'
          : e.toString().contains('USER_NOT_FOUND')
              ? '사용자를 찾을 수 없습니다.'
              : '삭제 실패';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _add(int targetId, String nickname) async {
    try {
      await FriendApi.addFriend(targetId);
      if (!mounted) return;
      // 요청 보낸 사용자 ID 추가
      setState(() {
        _pendingRequestUserIds.add(targetId);
        // 검색 결과에도 반영
        _results = _results.map((e) {
          if ((e['userId'] as int) == targetId) {
            return {...e, 'isRequestPending': true};
          }
          return e;
        }).toList();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('친구 요청을 보냈습니다: $nickname')));
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      String msg;
      if (s.contains('ALREADY_FRIEND')) {
        msg = '이미 친구입니다.';
      } else if (s.contains('REQUEST_ALREADY_EXISTS')) {
        msg = '이미 친구 요청을 보냈습니다.';
        // 이미 요청을 보낸 경우 상태 업데이트
        setState(() {
          _pendingRequestUserIds.add(targetId);
          _results = _results.map((e) {
            if ((e['userId'] as int) == targetId) {
              return {...e, 'isRequestPending': true};
            }
            return e;
          }).toList();
        });
      } else if (s.contains('USER_NOT_FOUND')) {
        msg = '사용자를 찾을 수 없습니다.';
      } else {
        // Exception: 접두사 제거
        if (s.startsWith('Exception: ')) {
          msg = s.substring('Exception: '.length);
        } else {
          msg = '친구 요청에 실패했습니다.';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _acceptByRequestId(int requestId, int requesterId, String nickname) async {
    try {
      await FriendApi.acceptRequest(requestId);
      final friend = {
        'userId': requesterId,
        'nickname': nickname,
        'email': null,
        'profileImageUrl': null,
        'addedAt': DateTime.now().toIso8601String(),
      };
      setState(() {
        // 요청 목록에서 제거
        _requests.removeWhere((e) => (e['requestId'] as int) == requestId);
        _dismissedRequestIds.add(requestId);
        // 내 친구 목록에 추가(중복 방지)
        final already =
            _friends.any((e) => (e['userId'] as int) == requesterId);
        if (!already) {
          _friends = [
            ..._friends,
            friend,
          ];
        }
        // 검색 결과에 반영
        _results = _results
            .map((e) => (e['userId'] as int) == requesterId
                ? {...e, 'isFriend': true}
                : e)
            .toList();
      });
      // 백엔드 연동 시 실제 상태 동기화를 위해 새로고침하되,
      // 수락된 요청은 로컬 필터로 재등장 방지
      await _loadFriends();
      await _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('요청 수락: $nickname')));
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      String msg;
      if (s.contains('UNAUTHORIZED')) {
        msg = '로그인이 필요합니다.';
      } else if (s.contains('USER_NOT_FOUND')) {
        msg = '사용자를 찾을 수 없습니다.';
      } else {
        // Exception: 접두사 제거
        if (s.startsWith('Exception: ')) {
          msg = s.substring('Exception: '.length);
        } else {
          msg = '요청 수락에 실패했습니다.';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _viewProfile(Map<String, dynamic> user) {
    final nick = (user['nickname'] ?? '') as String;
    final email = (user['email'] ?? '') as String?;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(nick),
        content: email == null ? const SizedBox.shrink() : Text(email),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('친구'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '내 친구'),
            Tab(text: '검색'),
            Tab(text: '요청'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 내 친구
          _buildFriendsTab(),
          // 검색
          _buildSearchTab(),
          // 받은 요청
          _buildRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_loading && _friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_friends.isEmpty) {
      return const Center(child: Text('친구가 없습니다.'));
    }
    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _friends.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final f = _friends[i];
          final id = f['userId'] as int;
          final nick = (f['nickname'] ?? '') as String;
          final email = (f['email'] ?? '') as String?;
          final avatar = (f['profileImageUrl'] ?? '') as String?;
          return ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
              child: (avatar == null || avatar.isEmpty)
                  ? const Icon(Icons.person_outline)
                  : null,
            ),
            title: Text(nick),
            subtitle:
                email == null ? null : Text(email, style: const TextStyle(fontSize: 12)),
            onTap: () => _viewProfile(f),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(id, nick),
              tooltip: '친구 삭제',
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: '닉네임/이메일로 검색',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (q) => _search(q.trim()),
          ),
        ),
        Expanded(
          child: _loading && _results.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final u = _results[i];
                        final id = u['userId'] as int;
                        final nick = (u['nickname'] ?? '') as String;
                        final email = (u['email'] ?? '') as String?;
                        final avatar = (u['profileImageUrl'] ?? '') as String?;
                        final isFriend = (u['isFriend'] as bool?) == true;
                        final isRequestPending = (u['isRequestPending'] as bool?) == true || 
                            _pendingRequestUserIds.contains(id);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (avatar != null && avatar.isNotEmpty)
                                ? NetworkImage(avatar)
                                : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? const Icon(Icons.person_outline)
                                : null,
                          ),
                          title: Text(nick),
                          subtitle: email == null
                              ? null
                              : Text(email, style: const TextStyle(fontSize: 12)),
                          onTap: () => _viewProfile(u),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFriend) ...[
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(id, nick),
                                  tooltip: '친구 삭제',
                                ),
                              ] else if (isRequestPending) ...[
                                TextButton(
                                  onPressed: null,
                                  child: const Text('요청중', style: TextStyle(color: Colors.grey)),
                                ),
                              ] else ...[
                                TextButton(
                                  onPressed: () => _add(id, nick),
                                  child: const Text('친구 요청'),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    if (_requests.isEmpty) {
      return const Center(child: Text('받은 친구 요청이 없습니다.'));
    }
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = _requests[i];
          final requestId = (r['requestId'] as int?) ?? -1;
          final id = r['userId'] as int;
          final nick = (r['nickname'] ?? '') as String;
          final email = (r['email'] ?? '') as String?;
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(nick),
            subtitle:
                email == null ? null : Text(email, style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: requestId <= 0 ? null : () => _acceptByRequestId(requestId, id, nick),
                  child: const Text('수락'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: requestId <= 0
                      ? null
                      : () async {
                          try {
                            await FriendApi.rejectRequest(requestId);
                            if (!mounted) return;
                            setState(() {
                              _requests.removeWhere((e) => (e['requestId'] as int) == requestId);
                              _dismissedRequestIds.add(requestId);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('요청을 거절했어요.')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            final s = e.toString();
                            String msg;
                            if (s.contains('REQUEST_NOT_FOUND')) {
                              msg = '요청을 찾을 수 없습니다.';
                            } else if (s.contains('FORBIDDEN')) {
                              msg = '권한이 없습니다.';
                            } else {
                              // Exception: 접두사 제거
                              if (s.startsWith('Exception: ')) {
                                msg = s.substring('Exception: '.length);
                              } else {
                                msg = '요청 거절에 실패했습니다.';
                              }
                            }
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                          }
                        },
                  child: const Text('거절', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


