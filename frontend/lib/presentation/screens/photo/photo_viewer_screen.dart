import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'photo_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/photo_provider.dart';
import 'package:frontend/services/photo_api.dart';
import 'photo_edit_screen.dart';
import 'package:frontend/providers/album_provider.dart';
import 'package:frontend/services/album_api.dart';
import 'package:frontend/providers/user_provider.dart';

class PhotoViewerScreen extends StatefulWidget {
  final int photoId;
  final String imageUrl;
  final int? albumId; // 앨범에서 진입 시 앨범 ID 전달
  const PhotoViewerScreen({
    super.key,
    required this.photoId,
    required this.imageUrl,
    this.albumId,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  bool _showUI = true;
  String? _myRole; // 앨범에서 진입한 경우 내 role 저장

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  @override
  void initState() {
    super.initState();
    // 앨범에서 진입한 경우 role 확인
    if (widget.albumId != null) {
      _loadMyRole();
    }
  }

  Future<void> _loadMyRole() async {
    if (widget.albumId == null) return;
    try {
      final albumProvider = context.read<AlbumProvider>();
      // 공유 앨범이 아니면 OWNER로 간주
      if (!albumProvider.isShared(widget.albumId!)) {
        if (mounted) {
          setState(() {
            _myRole = 'OWNER';
          });
        }
        return;
      }
      // 공유 앨범인 경우 Provider에 저장된 role 확인
      final cachedRole = albumProvider.myRoleOf(widget.albumId!);
      if (cachedRole != null && cachedRole.isNotEmpty) {
        if (mounted) {
          setState(() {
            _myRole = cachedRole.toUpperCase();
          });
        }
        return;
      }
      // Provider에 없으면 API로 조회
      final me = context.read<UserProvider>().userId;
      final members = await AlbumApi.getShareMembers(widget.albumId!);
      String? role;
      if (me != null) {
        final mine = members.cast<Map<String, dynamic>?>().firstWhere(
          (m) => m != null && m['userId'] == me,
          orElse: () => null,
        );
        if (mine != null && mine['role'] != null) {
          role = (mine['role'] as String).toUpperCase();
        }
      }
      role ??= 'VIEWER';
      if (mounted) {
        setState(() {
          _myRole = role;
        });
      }
    } catch (e) {
      // 에러 발생 시 기본값으로 VIEWER 설정
      if (mounted) {
        setState(() {
          _myRole = 'VIEWER';
        });
      }
    }
  }

  // 편집 가능 여부 확인
  bool get _canEdit {
    // 앨범에서 진입하지 않은 경우 (일반 사진 목록에서 진입) 편집 가능
    if (widget.albumId == null) return true;
    // 앨범에서 진입한 경우 role이 OWNER인지 확인
    return _myRole == 'OWNER';
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(widget.imageUrl);
    final isFile = uri == null || !uri.hasScheme;
    final Widget img = isFile
        ? Image.file(File(widget.imageUrl), fit: BoxFit.contain)
        : Image.network(widget.imageUrl, fit: BoxFit.contain);
    final isFav = context.select<PhotoProvider, bool>((p) {
      final idx = p.items.indexWhere((e) => e.photoId == widget.photoId);
      return idx != -1 ? p.items[idx].favorite : false;
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleUI,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(child: img),
                ),
              ),
            ),
            // 위로 스와이프하면 상세 Half-sheet 열기
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragEnd: (d) {
                  if (d.primaryVelocity != null && d.primaryVelocity! < -300) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      isDismissible: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DetailSheetModal(photoId: widget.photoId),
                    );
                  }
                },
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: AnimatedOpacity(
                opacity: _showUI ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: AnimatedOpacity(
                opacity: _showUI ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_showUI,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '즐겨찾기',
                              icon: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // 테두리용 검은색 하트 (약간 크게)
                                  Icon(
                                    isFav
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: Colors.black.withOpacity(0.5),
                                    size: 26,
                                  ),
                                  // 앞에 배치할 흰색 하트
                                  Icon(
                                    isFav
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ],
                              ),
                              onPressed: () async {
                                try {
                                  final api = PhotoApi();
                                  final response = await api.toggleFavorite(
                                    widget.photoId,
                                  );
                                  if (!context.mounted) return;
                                  // API 명세서: { photoId, isFavorite, message }
                                  final isFavorite =
                                      response['isFavorite'] as bool? ?? false;
                                  context
                                      .read<PhotoProvider>()
                                      .updateFromResponse({
                                        'photoId': widget.photoId,
                                        'favorite': isFavorite,
                                        'isFavorite': isFavorite,
                                      });
                                  // 성공 시 토스트 메시지 제거
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('즐겨찾기 실패: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                            IconButton(
                              tooltip: '상세',
                              icon: const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  isDismissible: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) =>
                                      DetailSheetModal(photoId: widget.photoId),
                                );
                              },
                            ),
                            // 공유 앨범에서 소유자가 아닌 경우 편집 버튼 숨김
                            if (_canEdit)
                              IconButton(
                                tooltip: '상세 편집',
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PhotoEditScreen(
                                        photoId: widget.photoId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            IconButton(
                              tooltip: widget.albumId != null
                                  ? '앨범에서 제거'
                                  : '삭제',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                              ),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(
                                      widget.albumId != null
                                          ? '앨범에서 제거'
                                          : '사진 삭제',
                                    ),
                                    content: Text(
                                      widget.albumId != null
                                          ? '이 사진을 앨범에서 제거하시겠습니까?'
                                          : '정말 삭제하시겠습니까?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('취소'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(
                                          widget.albumId != null ? '제거' : '삭제',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true && context.mounted) {
                                  try {
                                    if (widget.albumId != null) {
                                      // 앨범에서 제거
                                      // ignore: use_build_context_synchronously
                                      await AlbumApi.removePhotos(
                                        albumId: widget.albumId!,
                                        photoIds: [widget.photoId],
                                      );
                                      if (!context.mounted) return;
                                      // 앨범 상태만 수정
                                      // ignore: use_build_context_synchronously
                                      context
                                          .read<AlbumProvider>()
                                          .removePhotos(widget.albumId!, [
                                            widget.photoId,
                                          ]);
                                    } else {
                                      final api = PhotoApi();
                                      await api.deletePhoto(widget.photoId);
                                      if (!context.mounted) return;
                                      context.read<PhotoProvider>().removeById(
                                        widget.photoId,
                                      );
                                    }
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          widget.albumId != null
                                              ? '앨범에서 제거했습니다.'
                                              : '사진이 성공적으로 삭제되었습니다.',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('실패: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
