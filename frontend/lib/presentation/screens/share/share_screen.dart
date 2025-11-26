import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/services/friend_api.dart';
import 'package:frontend/services/album_api.dart';
import 'package:frontend/providers/album_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:frontend/presentation/screens/album/album_detail_screen.dart';
import 'package:frontend/presentation/screens/share/year_recap_screen.dart';
import 'package:frontend/presentation/screens/share/timeline_screen.dart';
import 'package:frontend/presentation/screens/notification/notification_bottom_sheet.dart';
import 'package:frontend/presentation/screens/share/share_requests_screen.dart';
import 'package:frontend/widgets/notification_badge_icon.dart';
import 'package:frontend/presentation/screens/album/album_members_screen.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: AppColors.secondary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _TopRow(),
                ),
                Divider(height: 1),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ShareAndInviteRow(),
                    const SizedBox(height: 20),
                    const _FriendsListSection(),
                    const SizedBox(height: 20),
                    const _CollaborativeAlbumSection(),
                    const SizedBox(height: 20),
                    _RecapTimelineSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'nemo',
          style: GoogleFonts.jua(fontSize: 24, color: AppColors.textPrimary),
        ),
        Row(
          children: [
            NotificationBadgeIcon(
              icon: Icons.notifications_outlined,
              color: AppColors.textPrimary,
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const NotificationBottomSheet(),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              color: AppColors.textPrimary,
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('설정 준비 중입니다.')));
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ShareAndInviteRow extends StatelessWidget {
  const _ShareAndInviteRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _OpenSheetTile(
            title: '앨범 공유',
            icon: Icons.share_outlined,
            subtitle: '링크/초대/권한 설정',
            onTap: () => _showShareAlbumSheet(context),
          ),
        ),
      ],
    );
  }
}

class _OpenSheetTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _OpenSheetTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendsListSection extends StatefulWidget {
  const _FriendsListSection();

  @override
  State<_FriendsListSection> createState() => _FriendsListSectionState();
}

class _FriendsListSectionState extends State<_FriendsListSection> {
  List<Map<String, dynamic>> _friends = const [];
  List<Map<String, dynamic>> _filtered = const [];
  List<Map<String, dynamic>> _searchResults = const []; // 검색 결과 (친구가 아닌 사용자 포함)
  bool _loading = true;
  bool _searching = false; // 검색 중 플래그
  String _sort = 'latest'; // latest | nickname
  final Set<int> _selected = {};
  String _searchQuery = ''; // 현재 검색어
  final Set<int> _pendingRequestUserIds = {}; // 친구 요청을 보낸 사용자 ID 목록

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await FriendApi.getFriends();
      _friends = list;
      _applySort();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySort() {
    _filtered = List.of(_friends);
    if (_sort == 'nickname') {
      _filtered.sort(
        (a, b) => (a['nickname'] ?? '').toString().compareTo(
          (b['nickname'] ?? '').toString(),
        ),
      );
    } else {
      _filtered.sort(
        (a, b) => (b['addedAt'] ?? '').toString().compareTo(
          (a['addedAt'] ?? '').toString(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '친구 찾기',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            DropdownButton<String>(
              value: _sort,
              items: const [
                DropdownMenuItem(value: 'latest', child: Text('최신순')),
                DropdownMenuItem(value: 'nickname', child: Text('닉네임순')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _sort = v;
                  _applySort();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: '친구 검색 (닉네임/이메일)',
            prefixIcon: Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          onChanged: (q) async {
            _searchQuery = q;
            if (q.trim().isEmpty) {
              setState(() {
                _searchResults = [];
                _applySort();
              });
            } else {
              // API를 통한 친구 검색 (친구가 아닌 사용자도 포함)
              setState(() => _searching = true);
              try {
                final results = await FriendApi.search(q.trim());
                if (mounted && _searchQuery == q) {
                  setState(() {
                    _searchResults = results;
                    _searching = false;
                  });
                }
              } catch (e) {
                if (mounted && _searchQuery == q) {
                  setState(() {
                    _searchResults = [];
                    _searching = false;
                  });
                  final errorStr = e.toString();
                  final msg = errorStr.startsWith('Exception: ')
                      ? errorStr.substring('Exception: '.length)
                      : '검색에 실패했습니다.';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                }
              }
            }
          },
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_searchQuery.trim().isNotEmpty)
          // 검색 모드: 검색 결과 표시 (친구가 아닌 사용자 포함)
          _searching
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _searchResults.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '검색 결과가 없습니다.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, i) {
                    final f = _searchResults[i];
                    final id = f['userId'] as int;
                    final nick = (f['nickname'] ?? '') as String;
                    final email = (f['email'] ?? '') as String;
                    final avatar = (f['profileImageUrl'] ?? '') as String?;
                    final isFriend = f['isFriend'] as bool? ?? false;
                    final isRequestPending =
                        (f['isRequestPending'] as bool?) == true ||
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
                      subtitle: Text(
                        email,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: isFriend
                          ? Checkbox(
                              value: _selected.contains(id),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                });
                              },
                            )
                          : isRequestPending
                          ? TextButton.icon(
                              icon: const Icon(Icons.hourglass_empty, size: 18),
                              label: const Text(
                                '요청중',
                                style: TextStyle(color: Colors.grey),
                              ),
                              onPressed: null,
                            )
                          : TextButton.icon(
                              icon: const Icon(Icons.person_add, size: 18),
                              label: const Text('요청'),
                              onPressed: () async {
                                try {
                                  await FriendApi.addFriend(id);
                                  if (!mounted) return;
                                  // 요청 보낸 사용자 ID 추가
                                  setState(() {
                                    _pendingRequestUserIds.add(id);
                                    // 검색 결과에도 반영
                                    _searchResults = _searchResults.map((e) {
                                      if ((e['userId'] as int) == id) {
                                        return {...e, 'isRequestPending': true};
                                      }
                                      return e;
                                    }).toList();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$nick님에게 친구 요청을 보냈습니다.'),
                                    ),
                                  );
                                  // 친구 목록 새로고침
                                  await _load();
                                  // 검색 결과도 업데이트
                                  if (_searchQuery.trim().isNotEmpty) {
                                    final results = await FriendApi.search(
                                      _searchQuery.trim(),
                                    );
                                    if (mounted) {
                                      setState(() {
                                        // 요청 보낸 사용자는 요청중 상태 유지
                                        _searchResults = results.map((e) {
                                          final userId = e['userId'] as int;
                                          if (_pendingRequestUserIds.contains(
                                            userId,
                                          )) {
                                            return {
                                              ...e,
                                              'isRequestPending': true,
                                            };
                                          }
                                          return e;
                                        }).toList();
                                      });
                                    }
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  final errorStr = e.toString();
                                  String errorMsg;
                                  if (errorStr.contains('ALREADY_FRIEND')) {
                                    errorMsg = '이미 친구입니다.';
                                  } else if (errorStr.contains(
                                    'REQUEST_ALREADY_EXISTS',
                                  )) {
                                    errorMsg = '이미 친구 요청을 보냈습니다.';
                                    // 이미 요청을 보낸 경우 상태 업데이트
                                    setState(() {
                                      _pendingRequestUserIds.add(id);
                                      _searchResults = _searchResults.map((e) {
                                        if ((e['userId'] as int) == id) {
                                          return {
                                            ...e,
                                            'isRequestPending': true,
                                          };
                                        }
                                        return e;
                                      }).toList();
                                    });
                                  } else if (errorStr.contains(
                                    'USER_NOT_FOUND',
                                  )) {
                                    errorMsg = '사용자를 찾을 수 없습니다.';
                                  } else {
                                    // Exception: 접두사 제거
                                    if (errorStr.startsWith('Exception: ')) {
                                      errorMsg = errorStr.substring(
                                        'Exception: '.length,
                                      );
                                    } else {
                                      errorMsg = '친구 요청에 실패했습니다.';
                                    }
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(errorMsg)),
                                  );
                                }
                              },
                            ),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: _searchResults.length,
                )
        else if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '친구가 없습니다.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          // 일반 모드: 친구 목록 표시
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, i) {
              final f = _filtered[i];
              final id = f['userId'] as int;
              final nick = (f['nickname'] ?? '') as String;
              final email = (f['email'] ?? '') as String;
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
                subtitle: Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: Checkbox(
                  value: _selected.contains(id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selected.add(id);
                      } else {
                        _selected.remove(id);
                      }
                    });
                  },
                ),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: _filtered.length,
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () async {
                        final friendIds = _selected.toList();
                        final albumId = await _pickAlbumId(context);
                        if (albumId == null) return;
                        try {
                          await AlbumApi.shareAlbum(
                            albumId: albumId,
                            friendIdList: friendIds,
                          );
                          if (!context.mounted) return;
                          _toast(
                            context,
                            '선택한 ${friendIds.length}명에게 공유되었습니다.',
                          );
                        } catch (e) {
                          final s = e.toString();
                          String msg;
                          if (s.contains('NOT_FRIEND')) {
                            msg = '친구로 등록되지 않은 사용자 포함';
                          } else if (s.contains('ALBUM_NOT_FOUND')) {
                            msg = '앨범을 찾을 수 없습니다';
                          } else if (s.contains('FORBIDDEN')) {
                            msg = '공유 권한이 없습니다';
                          } else {
                            // Exception: 접두사 제거
                            if (s.startsWith('Exception: ')) {
                              msg = s.substring('Exception: '.length);
                            } else {
                              msg = '공유에 실패했습니다.';
                            }
                          }
                          _toast(context, msg);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '선택한 친구에게 공유',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Bottom sheets
Future<void> _showShareAlbumSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    barrierColor: Colors.black26,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BottomSheetScaffold(child: _ShareAlbumSheet()),
  );
}

class _BottomSheetScaffold extends StatelessWidget {
  final Widget child;
  const _BottomSheetScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: SizedBox(
                  height: 24,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        );
      },
    );
  }
}

class _ShareAlbumSheet extends StatelessWidget {
  const _ShareAlbumSheet();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '앨범 공유',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _CircleIconButton(
              icon: Icons.message_outlined,
              onTap: () => _toast(context, '메신저 공유 준비 중'),
            ),
            const SizedBox(width: 8),
            _CircleIconButton(
              icon: Icons.mail_outline,
              onTap: () => _toast(context, '메일 공유 준비 중'),
            ),
            const SizedBox(width: 8),
            _CircleIconButton(
              icon: Icons.upload_outlined,
              onTap: () => _toast(context, '공유 URL 생성'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ActionButton(
          label: '선택 후 URL 생성',
          onTap: () => _handleCreateShareLink(context),
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: '참여자 추가',
          onTap: () => _handleAddParticipants(context),
        ),
      ],
    );
  }
}

// Handlers for Share actions
Future<void> _handleCreateShareLink(BuildContext context) async {
  final albumId = await _pickAlbumId(context);
  if (albumId == null) return;
  if (!context.mounted) return;
  try {
    final link = await AlbumApi.createShareLink(albumId, expiryHours: 48);
    if (link.isEmpty) {
      _toast(context, '링크 생성은 완료되었지만 주소를 받지 못했어요.');
      return;
    }
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('공유 링크 생성됨'),
        content: SelectableText(link),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              Navigator.pop(context);
              _toast(context, '링크가 복사되었습니다.');
            },
            child: const Text('복사'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  } catch (e) {
    final s = e.toString();
    String msg;
    if (s.contains('ALBUM_NOT_FOUND')) {
      msg = '앨범을 찾을 수 없습니다.';
    } else if (s.contains('FORBIDDEN')) {
      msg = '해당 앨범을 공유할 권한이 없습니다.';
    } else {
      // Exception: 접두사 제거
      if (s.startsWith('Exception: ')) {
        msg = s.substring('Exception: '.length);
      } else {
        msg = '링크 생성에 실패했습니다.';
      }
    }
    if (!context.mounted) return;
    _toast(context, msg);
  }
}

Future<void> _handleAddParticipants(BuildContext context) async {
  final albumId = await _pickAlbumId(context);
  if (albumId == null) return;
  if (!context.mounted) return;

  // 다른 참여자가 있는 앨범일 수 있으므로 승인 요청 안내
  final proceed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('참여자 추가'),
      content: const Text('다른 참여자가 있는 앨범일 경우, 추가에 대한 승인 요청이 전송될 수 있어요. 진행할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('진행'),
        ),
      ],
    ),
  );
  if (proceed != true) return;

  await _openFriendPickerAndShare(context, albumId: albumId);
}

Future<void> _openFriendPickerAndShare(
  BuildContext context, {
  required int albumId,
}) async {
  // 친구 선택
  final selected = await showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FriendPickerSheet(albumId: albumId),
  );
  if (selected == null || selected.isEmpty) return;
  if (!context.mounted) return;
  try {
    await AlbumApi.shareAlbum(
      albumId: albumId,
      friendIdList: selected.toList(),
    );
    _toast(context, '선택한 ${selected.length}명에게 공유되었습니다.');
    // 공유 후 상세로 이동하여 관리하도록 유도
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AlbumDetailScreen(albumId: albumId, autoOpenAction: 'share'),
      ),
    );
  } catch (e) {
    final s = e.toString();
    String msg;
    if (s.contains('NOT_FRIEND')) {
      msg = '친구로 등록되지 않은 사용자 포함';
    } else if (s.contains('ALBUM_NOT_FOUND')) {
      msg = '앨범을 찾을 수 없습니다';
    } else if (s.contains('FORBIDDEN')) {
      msg = '공유 권한이 없습니다';
    } else {
      // Exception: 접두사 제거
      if (s.startsWith('Exception: ')) {
        msg = s.substring('Exception: '.length);
      } else {
        msg = '공유에 실패했습니다.';
      }
    }
    _toast(context, msg);
  }
}

Future<int?> _pickAlbumId(BuildContext context) async {
  final id = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AlbumPickerSheet(),
  );
  return id;
}

// Removed unused: _ActionOption, _ActionChoiceSheet

class _AlbumPickerSheet extends StatelessWidget {
  const _AlbumPickerSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlbumProvider>();
    if (provider.albums.isEmpty && !provider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.read<AlbumProvider>().resetAndLoad();
      });
    }
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '앨범 선택',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: provider.albums.length,
                  itemBuilder: (_, i) {
                    final a = provider.albums[i];
                    return ListTile(
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: a.coverPhotoUrl != null
                              ? Image.network(
                                  a.coverPhotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: Colors.grey[200]),
                                )
                              : Container(color: Colors.grey[200]),
                        ),
                      ),
                      title: Text(a.title),
                      subtitle: Text('${a.photoCount}장'),
                      onTap: () => Navigator.pop<int>(context, a.albumId),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FriendPickerSheet extends StatefulWidget {
  final int albumId;
  const _FriendPickerSheet({required this.albumId});

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  final TextEditingController _search = TextEditingController();
  final Set<int> _selected = {};
  List<Map<String, dynamic>> _friends = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await FriendApi.getFriends();
      if (!mounted) return;
      setState(() {
        _friends = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(context, '친구 목록을 불러오지 못했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.text.trim().isEmpty
        ? _friends
        : _friends
              .where(
                (f) =>
                    (f['nickname'] ?? '').toString().contains(_search.text) ||
                    (f['email'] ?? '').toString().contains(_search.text),
              )
              .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '참여자 선택',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: '친구 검색',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          controller: controller,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final f = filtered[i];
                            final id = f['userId'] as int;
                            final nick = (f['nickname'] ?? '') as String;
                            final avatar =
                                (f['profileImageUrl'] ?? '') as String?;
                            final checked = _selected.contains(id);
                            return CheckboxListTile(
                              value: checked,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                });
                              },
                              title: Text(nick),
                              secondary: CircleAvatar(
                                backgroundColor: Colors.grey.shade300,
                                child: (avatar != null && avatar.isNotEmpty)
                                    ? ClipOval(
                                        child: Image.network(
                                          avatar,
                                          width: 36,
                                          height: 36,
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
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(height: 1),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop<Set<int>>(context, _selected),
                      child: Text('선택한 ${_selected.length}명 추가'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Removed unused: _FriendsTagSection

class _CollaborativeAlbumSection extends StatefulWidget {
  const _CollaborativeAlbumSection();

  @override
  State<_CollaborativeAlbumSection> createState() =>
      _CollaborativeAlbumSectionState();
}

class _CollaborativeAlbumSectionState
    extends State<_CollaborativeAlbumSection> {
  int _pendingCount = 0;
  bool _loading = true;
  bool _loadingList = true;
  List<Map<String, dynamic>> _shared = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadingList = true;
    });
    try {
      final reqs = await AlbumApi.getShareRequests();
      final shared = await AlbumApi.getSharedAlbums(page: 0, size: 20);
      // Provider의 공유 앨범 역할 스냅샷도 최신화 (상세에서 즉시 참조 가능)
      try {
        // ignore: use_build_context_synchronously
        await context.read<AlbumProvider>().refreshSharedAlbums();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _pendingCount = reqs.length;
        _shared = shared;
        _loading = false;
        _loadingList = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingList = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShareRequestsScreen()),
            );
            if (mounted) _loadAll(); // 돌아오면 카운트/목록 리프레시
          },
          child: Row(
            children: [
              const _SectionTitle(title: '공유 앨범'),
              const SizedBox(width: 8),
              if (!_loading && _pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$_pendingCount',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_loading && _loadingList)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_shared.isEmpty)
          const Text(
            '아직 공유중인 앨범이 없습니다.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _shared.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final a = _shared[i];
              final albumId = a['albumId'] as int;
              final title = a['title']?.toString() ?? '앨범';
              final cover = a['coverPhotoUrl'] as String?;
              final count = a['photoCount']?.toString() ?? '';
              final role = a['myRole']?.toString() ?? 'VIEWER';
              String roleKo;
              switch (role) {
                case 'OWNER':
                  roleKo = '소유주';
                  break;
                case 'CO_OWNER':
                  roleKo = '공동 소유주';
                  break;
                case 'EDITOR':
                  roleKo = '수정 가능';
                  break;
                default:
                  roleKo = '보기 가능';
              }
              final isOwnerLike = role == 'OWNER' || role == 'CO_OWNER';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 6,
                ),
                leading: SizedBox(
                  width: 56,
                  height: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: cover != null && cover.isNotEmpty
                        ? Image.network(
                            cover,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.grey[200]),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.photo_library_outlined),
                          ),
                  ),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '$roleKo · ${count}장',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: isOwnerLike
                    ? IconButton(
                        tooltip: '멤버 조회',
                        icon: const Icon(Icons.group_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AlbumMembersScreen(albumId: albumId),
                            ),
                          );
                        },
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  // 상세 진입 전 Provider에 기본 메타를 주입하여
                  // 상세 API 목업 제목이 기존 제목을 덮어쓰지 않도록 예방
                  context.read<AlbumProvider>().addFromResponse({
                    'albumId': albumId,
                    'title': title,
                    'description': a['description']?.toString() ?? '',
                    'coverPhotoUrl': cover,
                    'photoCount': int.tryParse(count) ?? 0,
                    'createdAt': a['createdAt']?.toString() ?? '',
                    'photoIdList': const <int>[],
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AlbumDetailScreen(albumId: albumId),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _RecapTimelineSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: '타임라인 / 연말 리캡 >'),
        const SizedBox(height: 10),
        _NavTile(
          title: '연말 리캡',
          subtitle: '올해의 추억 하이라이트',
          icon: Icons.auto_awesome_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const YearRecapScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        _NavTile(
          title: '타임라인',
          subtitle: '시간순 사진/앨범 보기',
          icon: Icons.timeline_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TimelineScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _NavTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// Removed unused: _PhotoTilePlaceholder

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// Removed unused: _showTopToast
