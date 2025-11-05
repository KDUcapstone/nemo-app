import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/services/friend_api.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _TopRow(),
          ),
          const Divider(height: 1),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ShareAndInviteRow(),
                    SizedBox(height: 20),
                    _FriendsListSection(),
                    SizedBox(height: 20),
                    _FriendsTagSection(),
                    SizedBox(height: 20),
                    _CollaborativeAlbumSection(),
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
  final Set<int> _inFlight = {};
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
                    : () {
                        final count = _selected.length;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('선택한 ${count}명에게 공유 초대 전송')),
                        );
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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('마이페이지 > 친구에서 관리하세요.')),
              );
            },
            child: const Text('친구 관리로 이동'),
          ),
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
          label: '공유 앨범 생성',
          onTap: () => _toast(context, '공유 앨범 생성'),
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: '공유 URL 생성',
          onTap: () async {
            final albumId = await _pickAlbumId(context);
            if (albumId == null) return;
            try {
              final res = await AlbumSharing.generateShareUrl(albumId: albumId);
              final url = (res['url'] ?? '').toString();
              if (url.isNotEmpty) {
                await Clipboard.setData(ClipboardData(text: url));
                if (!context.mounted) return;
                _showTopToast(context, '공유 URL이 클립보드에 복사되었습니다');
              } else {
                if (!context.mounted) return;
                _showTopToast(context, 'URL 생성 실패: 빈 URL');
              }
            } catch (e) {
              _showTopToast(context, 'URL 생성 실패: $e');
            }
          },
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: '공유 대상 추가',
          onTap: () => _toast(context, '공유 대상 추가'),
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

class _FriendsTagSection extends StatelessWidget {
  const _FriendsTagSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: '친구 태그 nemo >',
          onTap: () => _toast(context, '친구 태그로 이동'),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(6, (index) => const _PhotoTilePlaceholder()),
        ),
      ],
    );
  }
}

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

class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  const _SectionTitle({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
    if (onTap == null) return text;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: text,
    );
  }
}

class _PhotoTilePlaceholder extends StatelessWidget {
  const _PhotoTilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

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
