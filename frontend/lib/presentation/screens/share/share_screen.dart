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
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              color: AppColors.textPrimary,
              onPressed: () => _showInviteStatusSheet(context),
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
  bool _loading = true;
  String _sort = 'latest'; // latest | nickname
  final Set<int> _selected = {};

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
              '친구 목록',
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
            if (q.trim().isEmpty) {
              setState(() => _applySort());
            } else {
              final results = await FriendApi.search(q);
              setState(() => _filtered = results);
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
        else if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '친구가 없습니다.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(
                                albumId: albumId,
                                autoOpenAction: 'share',
                              ),
                            ),
                          );
                        } catch (e) {
                          final s = e.toString();
                          final msg = s.contains('NOT_FRIEND')
                              ? '친구로 등록되지 않은 사용자 포함'
                              : s.contains('ALBUM_NOT_FOUND')
                              ? '앨범을 찾을 수 없습니다'
                              : s.contains('FORBIDDEN')
                              ? '공유 권한이 없습니다'
                              : '공유 실패: $e';
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

Future<void> _showInviteStatusSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    barrierColor: Colors.black26,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BottomSheetScaffold(child: _InviteStatusSheet()),
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

class _InviteStatusSheet extends StatelessWidget {
  const _InviteStatusSheet();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '초대 현황',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '친구들로부터 공유 초대가 있습니다.',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _toast(context, '승인'),
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.redAccent),
                onPressed: () => _toast(context, '거절'),
              ),
            ],
          ),
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
    final msg = s.contains('ALBUM_NOT_FOUND')
        ? '앨범을 찾을 수 없습니다.'
        : s.contains('FORBIDDEN')
        ? '해당 앨범을 공유할 권한이 없습니다.'
        : '링크 생성 실패: $e';
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
    final msg = s.contains('NOT_FRIEND')
        ? '친구로 등록되지 않은 사용자 포함'
        : s.contains('ALBUM_NOT_FOUND')
        ? '앨범을 찾을 수 없습니다'
        : s.contains('FORBIDDEN')
        ? '공유 권한이 없습니다'
        : '공유 실패: $e';
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

class _CollaborativeAlbumSection extends StatelessWidget {
  const _CollaborativeAlbumSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _SectionTitle(title: '협업 앨범 (준비 중)'),
        SizedBox(height: 8),
        Text(
          '협업 앨범은 아직 준비 중입니다.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
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
