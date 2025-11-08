import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/photo_provider.dart';
import 'photo_viewer_screen.dart';
import 'package:frontend/presentation/screens/album/create_album_screen.dart';
import 'package:frontend/presentation/screens/album/select_album_photos_screen.dart';
import 'package:frontend/providers/album_provider.dart';
import 'package:frontend/presentation/screens/album/album_detail_screen.dart';
import 'package:frontend/services/album_api.dart';
import 'package:frontend/app/theme/app_colors.dart';

class PhotoListScreen extends StatefulWidget {
  const PhotoListScreen({super.key});

  @override
  State<PhotoListScreen> createState() => _PhotoListScreenState();
}

class _PhotoListScreenState extends State<PhotoListScreen> {
  bool _showAlbums = false;
  String _sort = 'takenAt,desc';
  String? _brand;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final p = context.read<PhotoProvider>();
        p.seedIfNeeded();
        p.fetchListIfNeeded();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<PhotoProvider>().items;
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with horizontal padding
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _TopBar(),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // 사진/앨범 전환 토글(정중앙 고정) + (앨범 모드) 새 앨범 버튼(우측 끝)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_showAlbums)
                      Positioned(
                        left: 0,
                        child: _BrandFilter(
                          value: _brand,
                          onChanged: (v) {
                            setState(() => _brand = v);
                            context.read<PhotoProvider>().resetAndLoad(
                              brand: v,
                            );
                          },
                        ),
                      ),
                    Center(
                      child: _TopToggle(
                        isAlbums: _showAlbums,
                        onChanged: (isAlbums) =>
                            setState(() => _showAlbums = isAlbums),
                      ),
                    ),
                    if (_showAlbums)
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: '새 앨범',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: () async {
                            // 1) 사진 먼저 선택
                            final selected = await Navigator.push<List<int>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SelectAlbumPhotosScreen(),
                              ),
                            );
                            if (!mounted) return;
                            if (selected == null) return;

                            // 2) 제목/설명 입력
                            final created = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateAlbumScreenInitial(
                                  selectedPhotoIds: selected,
                                ),
                              ),
                            );
                            if (!mounted) return;
                            if (created != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('앨범이 생성되었습니다.')),
                              );
                            }
                          },
                        ),
                      ),
                    if (!_showAlbums)
                      Positioned(
                        right: 0,
                        child: _SortDropdown(
                          value: _sort,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _sort = v);
                            context.read<PhotoProvider>().resetAndLoad(sort: v);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Stack(
                  children: [
                    items.isEmpty
                        ? const _EmptyState()
                        : (_showAlbums
                              ? const _AlbumListGrid()
                              : NotificationListener<ScrollNotification>(
                                  onNotification: (n) {
                                    if (n.metrics.pixels >=
                                        n.metrics.maxScrollExtent - 200) {
                                      final p = context.read<PhotoProvider>();
                                      if (!p.isLoading && p.hasMore) {
                                        p.loadNextPage();
                                      }
                                    }
                                    return false;
                                  },
                                  child: Consumer<PhotoProvider>(
                                    builder: (_, p, __) => Stack(
                                      children: [
                                        GridView.builder(
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                mainAxisSpacing: 20,
                                                crossAxisSpacing: 20,
                                                childAspectRatio: 0.72,
                                              ),
                                          itemCount: items.length,
                                          itemBuilder: (_, i) {
                                            final item = items[i];
                                            return _PhotoCard(
                                              item: item,
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        PhotoViewerScreen(
                                                          photoId: item.photoId,
                                                          imageUrl:
                                                              item.imageUrl,
                                                        ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                        if (p.isLoading)
                                          const Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            child: Padding(
                                              padding: EdgeInsets.all(8),
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopToggle extends StatelessWidget {
  final bool isAlbums;
  final ValueChanged<bool> onChanged;
  const _TopToggle({required this.isAlbums, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ToggleButtons(
      isSelected: [!isAlbums, isAlbums],
      onPressed: (idx) => onChanged(idx == 1),
      borderRadius: BorderRadius.circular(20),
      constraints: const BoxConstraints(minHeight: 36, minWidth: 88),
      selectedColor: scheme.onPrimary,
      fillColor: scheme.primary,
      color: scheme.onSurface.withOpacity(0.8),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('사진'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('앨범'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('아직 업로드된 사진이 없습니다'),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
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
              icon: const Icon(Icons.notifications_none_rounded),
              color: AppColors.textPrimary,
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('알림 준비 중입니다.')));
              },
            ),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              color: AppColors.textPrimary,
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('도움말 준비 중입니다.')));
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandFilter extends StatelessWidget {
  final String? value; // null = 전체
  final ValueChanged<String?> onChanged;
  const _BrandFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const brands = <String?>[null, '인생네컷', '포토이즘', '포토그레이'];
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        border: Border.all(color: AppColors.divider, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: PopupMenuButton<String?>(
          padding: EdgeInsets.zero,
          color: AppColors.secondary,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          onSelected: (v) => onChanged(v),
          itemBuilder: (ctx) => brands
              .map(
                (b) => PopupMenuItem<String?>(
                  value: b,
                  child: Text(
                    b ?? '전체',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          child: const SizedBox(
            height: 28,
            child: Center(
              child: Text(
                '🏷️',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final String value; // 'takenAt,desc' | 'takenAt,asc'
  final ValueChanged<String?> onChanged;
  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const sorts = <Map<String, String>>[
      {'value': 'takenAt,desc', 'label': '최신순'},
      {'value': 'takenAt,asc', 'label': '오래된순'},
    ];
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        border: Border.all(color: AppColors.divider, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          color: AppColors.secondary,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          onSelected: (v) => onChanged(v),
          itemBuilder: (ctx) => sorts
              .map(
                (m) => PopupMenuItem<String>(
                  value: m['value']!,
                  child: Text(
                    m['label']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          child: const SizedBox(
            height: 28,
            child: Center(
              child: Text(
                '📅',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final PhotoItem item;
  final VoidCallback onTap;
  const _PhotoCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isFile =
        item.imageUrl.isNotEmpty && !item.imageUrl.startsWith('http');
    final imageWidget = _Thumb(imageUrl: item.imageUrl, isFile: isFile);

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(color: Colors.grey[200], child: imageWidget),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [if (item.favorite) const _FavoriteBadge()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String imageUrl;
  final bool isFile;
  const _Thumb({required this.imageUrl, required this.isFile});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const _ThumbFallback();
    if (isFile) {
      final file = File(imageUrl);
      if (!file.existsSync()) return const _ThumbFallback();
      return Image.file(
        file,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) => const _ThumbFallback(),
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
      );
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) => const _ThumbFallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
      );
    }
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.grey),
      ),
    );
  }
}

class _DeleteButton extends StatefulWidget {
  final int photoId;
  const _DeleteButton({required this.photoId});

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.favorite, color: Colors.white, size: 18);
  }
}

class _DeleteButtonState extends State<_DeleteButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _loading
          ? null
          : () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('사진 삭제'),
                  content: const Text('정말 삭제하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              setState(() => _loading = true);
              try {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('삭제 요청 완료')));
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.black45,
        child: _loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.delete_outline, color: Colors.white, size: 18),
      ),
    );
  }
}

class _AlbumListGrid extends StatefulWidget {
  const _AlbumListGrid();

  @override
  State<_AlbumListGrid> createState() => _AlbumListGridState();
}

class _AlbumListGridState extends State<_AlbumListGrid> {
  int? _pressedIndex;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlbumProvider>();
    if (provider.albums.isEmpty && !provider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AlbumProvider>().resetAndLoad();
        }
      });
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          if (!provider.isLoading && provider.hasMore) {
            provider.loadNextPage();
          }
        }
        return false;
      },
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 0.78,
        ),
        itemCount: provider.albums.length,
        itemBuilder: (_, i) {
          final a = provider.albums[i];
          final scale = _pressedIndex == i ? 0.96 : 1.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AnimatedScale(
                  scale: scale,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AlbumDetailScreen(albumId: a.albumId),
                          ),
                        );
                      },
                      onLongPress: () async {
                        setState(() => _pressedIndex = i);
                        await Future.delayed(const Duration(milliseconds: 90));
                        final action = await showModalBottomSheet<String>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => _AlbumQuickActions(album: a),
                        );
                        if (!mounted) return;
                        setState(() => _pressedIndex = null);
                        if (action == null) return;
                        if (action == 'share' || action == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(
                                albumId: a.albumId,
                                autoOpenAction: action,
                              ),
                            ),
                          );
                        } else if (action == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('앨범 삭제'),
                              content: const Text('이 앨범을 삭제하시겠습니까?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            try {
                              await AlbumApi.deleteAlbum(a.albumId);
                              if (!mounted) return;
                              context.read<AlbumProvider>().removeAlbum(
                                a.albumId,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('앨범이 삭제되었습니다.')),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('삭제 실패: $e')),
                              );
                            }
                          }
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: a.coverPhotoUrl != null
                                  ? Image.network(
                                      a.coverPhotoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const ColoredBox(
                                            color: Color(0xFFE0E0E0),
                                          ),
                                    )
                                  : const ColoredBox(color: Color(0xFFE0E0E0)),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 56,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black26,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                a.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${a.photoCount}장',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AlbumQuickActions extends StatelessWidget {
  final AlbumItem album;
  const _AlbumQuickActions({required this.album});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('공유'),
                onTap: () => Navigator.pop(context, 'share'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('수정'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('삭제'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _FloatingSortButton 제거됨: 상단 우측 드롭다운으로 대체
