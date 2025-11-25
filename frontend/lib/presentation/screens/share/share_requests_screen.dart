import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/album_api.dart';
import 'package:frontend/presentation/screens/album/album_detail_screen.dart';

class ShareRequestsScreen extends StatefulWidget {
  const ShareRequestsScreen({super.key});
  @override
  State<ShareRequestsScreen> createState() => _ShareRequestsScreenState();
}

class _ShareRequestsScreenState extends State<ShareRequestsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

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
      final list = await AlbumApi.getShareRequests();
      if (!mounted) return;
      setState(() {
        _items = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '요청 목록을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(int albumId, int index) async {
    try {
      await AlbumApi.acceptShare(albumId);
      if (!mounted) return;
      setState(() {
        _items.removeAt(index);
      });
      _showTopToast('앨범 공유를 수락했습니다.');
      // 공유 수락 후 바로 앨범 상세 화면으로 이동
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AlbumDetailScreen(albumId: albumId),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      final msg = s.contains('INVITE_NOT_FOUND')
          ? '공유 요청을 찾을 수 없습니다.'
          : s.contains('ALREADY_ACCEPTED')
          ? '이미 멤버로 참여 중입니다.'
          : s.contains('FORBIDDEN')
          ? '권한이 없습니다.'
          : '수락 실패: $e';
      _showTopToast(msg);
    }
  }

  Future<void> _reject(int albumId, int index) async {
    try {
      await AlbumApi.rejectShare(albumId);
      if (!mounted) return;
      setState(() {
        _items.removeAt(index);
      });
      _showTopToast('공유 요청을 거절했습니다.');
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      final msg = s.contains('INVITE_NOT_FOUND')
          ? '공유 요청을 찾을 수 없습니다.'
          : s.contains('FORBIDDEN')
          ? '권한이 없습니다.'
          : '거절 실패: $e';
      _showTopToast(msg);
    }
  }

  void _showTopToast(String message) {
    final overlay = Overlay.of(context);
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
    overlay.insert(entry);
    Future.delayed(
      const Duration(milliseconds: 1500),
    ).then((_) => entry.remove());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공유 요청')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _items.isEmpty
          ? const Center(child: Text('대기 중인 공유 요청이 없습니다.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = _items[i];
                  final albumId = it['albumId'] as int;
                  final title = it['albumTitle']?.toString() ?? '앨범';
                  final inviter =
                      (it['invitedBy'] as Map?)?['nickname']?.toString() ??
                      '친구';
                  final role = (it['inviteRole']?.toString() ?? 'VIEWER')
                      .toUpperCase();
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
                  final invitedAt = it['invitedAt']?.toString();
                  final when = invitedAt != null
                      ? DateFormat(
                          'MM/dd HH:mm',
                        ).format(DateTime.parse(invitedAt).toLocal())
                      : '';
                  return ListTile(
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('$inviter · 내 권한: $roleKo · $when'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlbumDetailScreen(albumId: albumId),
                        ),
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '수락',
                          onPressed: () => _accept(albumId, i),
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                        IconButton(
                          tooltip: '거절',
                          onPressed: () => _reject(albumId, i),
                          icon: const Icon(
                            Icons.cancel,
                            color: Colors.redAccent,
                          ),
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
