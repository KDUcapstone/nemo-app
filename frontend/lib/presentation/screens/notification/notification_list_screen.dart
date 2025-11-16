import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:frontend/models/notification_models.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/presentation/screens/photo/photo_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/app/theme/app_colors.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});
  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<NotificationProvider>();
      p.refresh();
    });
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final p = context.read<NotificationProvider>();
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      p.loadMore();
    }
  }

  Future<void> _onTapItem(NotificationItem item) async {
    final provider = context.read<NotificationProvider>();
    await provider.markRead(item);
    // actionType + target 기반 라우팅
    switch (item.actionType) {
      case ActionType.OPEN_PHOTO:
        if (item.target?.type == TargetType.PHOTO && mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PhotoDetailScreen(photoId: item.target!.id),
          ));
        }
        break;
      case ActionType.OPEN_ALBUM:
        // TODO: 앨범 상세 화면 연결 시 교체
        _toast('앨범 상세로 이동 (미연결)');
        break;
      case ActionType.OPEN_FRIEND_REQUEST:
        // TODO: 친구 요청 화면 연결 시 교체
        _toast('친구 요청 화면으로 이동 (미연결)');
        break;
      default:
        break;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, p, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: AppColors.secondary,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'nemo',
                              style: GoogleFonts.jua(fontSize: 24, color: AppColors.textPrimary),
                            ),
                            Row(
                              children: [
                                if (p.unreadCount > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${p.unreadCount}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                IconButton(
                                  tooltip: '모두 읽음',
                                  onPressed: p.unreadCount == 0 ? null : () => p.markAllRead(),
                                  icon: const Icon(Icons.mark_email_read_outlined),
                                  color: AppColors.textPrimary,
                                ),
                                const SizedBox(width: 4),
                                const Text('읽지 않음만'),
                                Switch(
                                  value: p.onlyUnread,
                                  onChanged: (v) => p.setOnlyUnread(v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: p.refresh,
                    child: p.loading && p.groups.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: _calcItemCount(p),
                            itemBuilder: (_, index) => _buildListItem(p, index),
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

  int _calcItemCount(NotificationProvider p) {
    // 그룹 헤더 + 아이템 합산
    int count = 0;
    for (final g in p.groups) {
      count += 1; // header
      count += g.items.length;
    }
    // 로딩 인디케이터 꼬리표
    if (p.loading && p.groups.isNotEmpty) count += 1;
    return count;
  }

  Widget _buildListItem(NotificationProvider p, int index) {
    int offset = 0;
    for (final g in p.groups) {
      if (index == offset) {
        return _GroupHeader(label: g.label);
      }
      offset += 1;
      final itemIndexInGroup = index - offset;
      if (itemIndexInGroup < g.items.length) {
        final item = g.items[itemIndexInGroup];
        return _NotificationTile(
          item: item,
          onTap: () => _onTapItem(item),
        );
      }
      offset += g.items.length;
    }
    // 꼬리 로딩
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      color: Colors.grey.shade100,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final created = DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt.toLocal());
    final subtitle = '$created';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: item.actor?.profileImageUrl != null
            ? NetworkImage(item.actor!.profileImageUrl!)
            : null,
        child: item.actor?.profileImageUrl == null ? const Icon(Icons.notifications_outlined) : null,
      ),
      title: Text(
        item.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: item.isRead
          ? const Icon(Icons.done_all, color: Colors.blueGrey, size: 18)
          : const Icon(Icons.brightness_1, color: Colors.redAccent, size: 10),
    );
  }
}


