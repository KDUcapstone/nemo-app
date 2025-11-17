import 'package:flutter/material.dart';
import 'package:frontend/services/album_api.dart';

class AlbumMembersScreen extends StatefulWidget {
  final int albumId;
  const AlbumMembersScreen({super.key, required this.albumId});
  @override
  State<AlbumMembersScreen> createState() => _AlbumMembersScreenState();
}

class _AlbumMembersScreenState extends State<AlbumMembersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _members = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AlbumApi.getShareMembers(widget.albumId);
      if (!mounted) return;
      list.sort((a, b) {
        int rank(String r) {
          switch (r) {
            case 'OWNER':
              return 0;
            case 'CO_OWNER':
              return 1;
            case 'EDITOR':
              return 2;
            default:
              return 3;
          }
        }
        return rank(a['role']?.toString() ?? 'VIEWER')
            .compareTo(rank(b['role']?.toString() ?? 'VIEWER'));
      });
      setState(() {
        _members = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '멤버 목록을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(int userId) async {
    final role = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _RoleSheet(),
    );
    if (role == null) return;
    try {
      await AlbumApi.updateSharePermission(
        albumId: widget.albumId,
        targetUserId: userId,
        role: role,
      );
      if (!mounted) return;
      setState(() {
        final idx = _members.indexWhere((e) => (e['userId'] as int) == userId);
        if (idx != -1) _members[idx] = {..._members[idx], 'role': role};
      });
      _showTopToast('권한이 $role(으)로 변경되었습니다.');
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      final msg = s.contains('INVALID_ROLE')
          ? '잘못된 권한 값입니다.'
          : s.contains('FORBIDDEN')
              ? '권한이 없습니다.'
              : '변경 실패: $e';
      _showTopToast(msg);
    }
  }

  Future<void> _remove(int userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('멤버 제거'),
        content: const Text('해당 사용자를 앨범에서 제거하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('제거')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AlbumApi.removeShareMember(albumId: widget.albumId, targetUserId: userId);
      if (!mounted) return;
      setState(() {
        _members.removeWhere((e) => (e['userId'] as int) == userId);
      });
      _showTopToast('멤버를 제거했습니다.');
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      final msg = s.contains('CANNOT_REMOVE_OWNER')
          ? '소유자는 제거할 수 없습니다.'
          : s.contains('FORBIDDEN')
              ? '권한이 없습니다.'
              : '제거 실패: $e';
      _showTopToast(msg);
    }
  }

  void _showTopToast(String message) {
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(milliseconds: 1500)).then((_) => entry.remove());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공유 멤버')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: _members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final m = _members[i];
                      final userId = m['userId'] as int;
                      final nick = m['nickname']?.toString() ?? 'user$userId';
                      final role = m['role']?.toString() ?? 'VIEWER';
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
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                        title: Text(nick),
                        subtitle: Text(roleKo),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '권한 변경',
                              onPressed: () => _changeRole(userId),
                              icon: const Icon(Icons.admin_panel_settings),
                            ),
                            IconButton(
                              tooltip: '제거',
                              onPressed: () => _remove(userId),
                              icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _RoleSheet extends StatelessWidget {
  final List<String> roles = const ['VIEWER', 'EDITOR', 'CO_OWNER'];

  String _label(String role) {
    switch (role) {
      case 'OWNER':
        return '소유주';
      case 'CO_OWNER':
        return '공동 소유주';
      case 'EDITOR':
        return '수정 가능';
      default:
        return '보기 가능';
    }
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: roles
            .map(
              (r) => ListTile(
                title: Text(_label(r)),
                onTap: () => Navigator.pop(context, r),
              ),
            )
            .toList(),
      ),
    );
  }
}


