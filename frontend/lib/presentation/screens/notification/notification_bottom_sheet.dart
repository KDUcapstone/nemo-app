import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/models/notification_models.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/presentation/screens/photo/photo_viewer_screen.dart';
import 'package:frontend/services/photo_api.dart';
import 'package:frontend/presentation/screens/album/album_detail_screen.dart';
import 'package:frontend/presentation/screens/user/friends_list_screen.dart';

class NotificationBottomSheet extends StatefulWidget {
  const NotificationBottomSheet({super.key});
  @override
  State<NotificationBottomSheet> createState() =>
      _NotificationBottomSheetState();
}

class _NotificationBottomSheetState extends State<NotificationBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationProvider>();
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
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '알림',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            p.unreadCount > 0
                                ? '안 읽음 ${p.unreadCount}'
                                : '모두 읽음',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: '모두 읽음',
                            icon: const Icon(Icons.mark_email_read_outlined),
                            onPressed: p.unreadCount == 0
                                ? null
                                : () => p.markAllRead(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: p.loading && p.groups.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                          itemCount: _calcItemCount(p),
                          itemBuilder: (_, index) => _buildListItem(p, index),
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
    int count = 0;
    for (final g in p.groups) {
      count += 1;
      count += g.items.length;
    }
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
        final isAlbumInvite = item.type == NotificationType.ALBUM_INVITE;
        return _NotificationTile(
          item: item,
          onTap: () => _onTapItem(item),
          onAccept: isAlbumInvite
              ? () async {
                  final provider = context.read<NotificationProvider>();
                  await provider.actOnAlbumInvite(item, accept: true);
                  if (!mounted) return;
                  _showTopToast(context, '앨범 초대를 수락했어요.');
                }
              : null,
          onDecline: isAlbumInvite
              ? () async {
                  final provider = context.read<NotificationProvider>();
                  await provider.actOnAlbumInvite(item, accept: false);
                  if (!mounted) return;
                  _showTopToast(context, '앨범 초대를 거절했어요.');
                }
              : null,
        );
      }
      offset += g.items.length;
    }
    return const SizedBox.shrink();
  }

  Future<void> _onTapItem(NotificationItem item) async {
    final provider = context.read<NotificationProvider>();
    await provider.markRead(item);
    switch (item.actionType) {
      case ActionType.OPEN_PHOTO:
        if (item.target?.type == TargetType.PHOTO && mounted) {
          // 사진 상세가 아닌 "사진 자체"로 바로 이동
          try {
            final res = await PhotoApi().getPhoto(item.target!.id);
            final imageUrl = (res['imageUrl'] ?? '') as String;
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PhotoViewerScreen(
                  photoId: item.target!.id,
                  imageUrl: imageUrl,
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            _showTopToast(context, '사진을 열 수 없습니다: $e');
          }
        }
        break;
      case ActionType.OPEN_ALBUM:
        if (item.target?.type == TargetType.ALBUM && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AlbumDetailScreen(albumId: item.target!.id),
            ),
          );
        }
        break;
      case ActionType.OPEN_FRIEND_REQUEST:
        if (!mounted) return;
        // 마이페이지 -> 친구 목록 -> 요청 탭으로 이동 (FriendsListScreen 활용)
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const FriendsListScreen(initialTabIndex: 2),
          ),
        );
        break;
      default:
        break;
    }
  }

  // 상단 토스트 (OverlayEntry) - 반시트에 가리지 않도록 상단에 표시
  void _showTopToast(BuildContext context, String message) {
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
}

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  const _NotificationTile({
    required this.item,
    required this.onTap,
    this.onAccept,
    this.onDecline,
  });
  @override
  Widget build(BuildContext context) {
    final created = DateFormat('MM/dd HH:mm').format(item.createdAt.toLocal());
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(
          item.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: item.isRead ? FontWeight.normal : FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
        subtitle: Builder(
          builder: (context) {
            if (item.type == NotificationType.ALBUM_INVITE) {
              final inviter = item.actor?.nickname ?? '친구';
              final role = (item.inviteRole ?? 'VIEWER').toUpperCase();
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
              return Text(
                '$inviter · 내 권한: $roleKo · $created',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            }
            return Text(
              created,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            );
          },
        ),
        trailing: (onAccept != null || onDecline != null)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '수락',
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                  ),
                  IconButton(
                    tooltip: '거절',
                    onPressed: onDecline,
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  ),
                ],
              )
            : (item.isRead
                  ? const Icon(Icons.done_all, color: Colors.blueGrey, size: 18)
                  : const Icon(
                      Icons.fiber_manual_record,
                      color: Colors.redAccent,
                      size: 12,
                    )),
      ),
    );
  }
}
