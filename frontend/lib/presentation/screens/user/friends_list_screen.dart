import 'package:flutter/material.dart';
import 'package:frontend/services/friend_api.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _friends = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() => _loading = true);
    try {
      final list = (search == null || search.trim().isEmpty)
          ? await FriendApi.getFriends() // 친구만 먼저
          : await FriendApi.search(search); // 검색 시 전체에서 검색
      setState(() => _friends = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('친구 목록을 불러오지 못했습니다: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int userId, String nickname) async {
    try {
      await FriendApi.deleteFriend(userId);
      setState(() => _friends.removeWhere((e) => e['userId'] == userId));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('친구 목록')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: '친구 검색 (닉네임/이메일)',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (q) => _load(search: q.trim()),
              onChanged: (q) {
                if (q.isEmpty) _load(search: null);
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _friends.isEmpty
                    ? const Center(child: Text('친구가 없습니다.'))
                    : ListView.separated(
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
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(id, nick),
                              tooltip: '친구 삭제',
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


