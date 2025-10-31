import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/services/friend_api.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _sortFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _loadingMore = false;
  List<Map<String, dynamic>> _allFriends = [];
  List<Map<String, dynamic>> _friends = [];
  int _pageSize = 20;
  String _sort = 'latest'; // 'latest' | 'nickname'

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _sortFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await FriendApi.getFriends();
      if (!mounted) return;
      setState(() {
        _allFriends = _normalize(list);
        _applySort();
        _friends = _allFriends.take(_pageSize).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('친구 목록을 불러오지 못했습니다: $e')));
    }
  }

  List<Map<String, dynamic>> _normalize(List<Map<String, dynamic>> items) {
    return items.map((e) {
      final map = Map<String, dynamic>.from(e);
      if (map['profileImageUrl'] == null && map['avatarUrl'] != null) {
        map['profileImageUrl'] = map['avatarUrl'];
      }
      return map;
    }).toList();
  }

  void _applySort() {
    if (_sort == 'nickname') {
      _allFriends.sort(
        (a, b) => (a['nickname'] ?? '').toString().toLowerCase().compareTo(
          (b['nickname'] ?? '').toString().toLowerCase(),
        ),
      );
    } else {
      // latest: addedAt desc if available
      _allFriends.sort((a, b) {
        final as = a['addedAt'];
        final bs = b['addedAt'];
        if (as == null || bs == null) return 0;
        final ad = DateTime.tryParse(as.toString());
        final bd = DateTime.tryParse(bs.toString());
        if (ad == null || bd == null) return 0;
        return bd.compareTo(ad);
      });
    }
  }

  void _onScroll() {
    if (_loadingMore || _loading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_friends.length >= _allFriends.length) return;
    setState(() => _loadingMore = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final next = _allFriends.skip(_friends.length).take(_pageSize).toList();
      setState(() {
        _friends.addAll(next);
        _loadingMore = false;
      });
    });
  }

  void _dismissFocus() {
    if (_searchFocus.hasFocus) {
      _searchFocus.unfocus();
    }
  }

  Future<void> _deleteFriend(int userId) async {
    try {
      await FriendApi.deleteFriend(userId);
      if (!mounted) return;
      setState(() {
        _friends.removeWhere((e) => e['userId'] == userId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구를 삭제했어요')));
    } catch (e) {
      String msg = '삭제 실패: $e';
      final s = e.toString();
      if (s.contains('NOT_A_FRIEND')) msg = '친구 목록에 없는 사용자입니다.';
      if (s.contains('USER_NOT_FOUND')) msg = '해당 사용자를 찾을 수 없습니다.';
      if (s.contains('UNAUTHORIZED')) msg = '로그인이 필요합니다.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissFocus,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text('친구 목록', style: GoogleFonts.jua()),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  focusNode: _sortFocus,
                  autofocus: false,
                  focusColor: Colors.transparent,
                  value: _sort,
                  items: const [
                    DropdownMenuItem(value: 'latest', child: Text('최근순')),
                    DropdownMenuItem(value: 'nickname', child: Text('닉네임순')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _sort = v;
                      _applySort();
                      _friends = _allFriends.take(_friends.length).toList();
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_sortFocus.hasFocus) _sortFocus.unfocus();
                      FocusManager.instance.primaryFocus?.unfocus();
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: const InputDecoration(
                  hintText: '친구 검색 (닉네임/이메일)',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) async {
                  final all = await FriendApi.list(search: v);
                  if (!mounted) return;
                  setState(() {
                    _allFriends = _normalize(all);
                    _applySort();
                    _friends = _allFriends.take(_pageSize).toList();
                  });
                },
                onTapOutside: (_) => _dismissFocus(),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        ListView.separated(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                          controller: _scrollController,
                          itemCount: _friends.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final f = _friends[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey.shade300,
                                child:
                                    (f['profileImageUrl'] is String &&
                                        (f['profileImageUrl'] as String)
                                            .isNotEmpty)
                                    ? ClipOval(
                                        child: Image.network(
                                          f['profileImageUrl'],
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.person_outline,
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person_outline,
                                        color: AppColors.textSecondary,
                                      ),
                              ),
                              title: Text(
                                f['nickname'] ?? '친구',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              // 이메일은 목록에서 숨김
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'profile') {
                                    _showProfile(f);
                                  } else if (value == 'delete') {
                                    _deleteFriend(f['userId'] as int);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'profile',
                                    child: Text('프로필 보기'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('삭제'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (_loadingMore)
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 8,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfile(Map<String, dynamic> f) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey.shade300,
                child:
                    (f['profileImageUrl'] is String &&
                        (f['profileImageUrl'] as String).isNotEmpty)
                    ? ClipOval(
                        child: Image.network(
                          f['profileImageUrl'],
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_outline,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person_outline,
                        color: AppColors.textSecondary,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                f['nickname'] ?? '친구',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (f['email'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  f['email'],
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
