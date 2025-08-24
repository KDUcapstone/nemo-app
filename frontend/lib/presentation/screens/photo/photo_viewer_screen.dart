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

class PhotoViewerScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(imageUrl);
    final isFile = uri == null || !uri.hasScheme;
    final Widget img = isFile
        ? Image.file(File(imageUrl), fit: BoxFit.contain)
        : Image.network(imageUrl, fit: BoxFit.contain);
    final isFav = context.select<PhotoProvider, bool>((p) {
      final idx = p.items.indexWhere((e) => e.photoId == photoId);
      return idx != -1 ? p.items[idx].favorite : false;
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(child: img),
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
                      builder: (_) => DetailSheetModal(photoId: photoId),
                    );
                  }
                },
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
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
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            try {
                              final api = PhotoApi();
                              final ok = await api.toggleFavorite(
                                photoId,
                                currentFavorite: isFav,
                              );
                              if (!context.mounted) return;
                              context.read<PhotoProvider>().updateFromResponse({
                                'photoId': photoId,
                                'favorite': ok,
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('즐겨찾기 상태가 변경되었습니다.'),
                                ),
                              );
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
                                  DetailSheetModal(photoId: photoId),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: '상세 편집',
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PhotoEditScreen(photoId: photoId),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: albumId != null ? '앨범에서 제거' : '삭제',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(
                                  albumId != null ? '앨범에서 제거' : '사진 삭제',
                                ),
                                content: Text(
                                  albumId != null
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
                                    child: Text(albumId != null ? '제거' : '삭제'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && context.mounted) {
                              try {
                                if (albumId != null) {
                                  // 앨범에서 제거
                                  // ignore: use_build_context_synchronously
                                  await AlbumApi.removePhotos(
                                    albumId: albumId!,
                                    photoIds: [photoId],
                                  );
                                  if (!context.mounted) return;
                                  // 앨범 상태만 수정
                                  // ignore: use_build_context_synchronously
                                  context.read<AlbumProvider>().removePhotos(
                                    albumId!,
                                    [photoId],
                                  );
                                } else {
                                  final api = PhotoApi();
                                  await api.deletePhoto(photoId);
                                  if (!context.mounted) return;
                                  context.read<PhotoProvider>().removeById(
                                    photoId,
                                  );
                                }
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      albumId != null
                                          ? '앨범에서 제거했습니다.'
                                          : '사진이 성공적으로 삭제되었습니다.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
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
          ],
        ),
      ),
    );
  }
}
