import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/photo_provider.dart';
import 'photo_viewer_screen.dart';
import 'package:frontend/presentation/screens/album/create_album_screen.dart';
import 'package:frontend/presentation/screens/album/select_album_photos_screen.dart';
import 'package:frontend/providers/album_provider.dart';
import 'package:frontend/presentation/screens/album/album_detail_screen.dart';

class PhotoListScreen extends StatefulWidget {
  const PhotoListScreen({super.key});

  @override
  State<PhotoListScreen> createState() => _PhotoListScreenState();
}

class _PhotoListScreenState extends State<PhotoListScreen> {
  bool _showAlbums = false;
  String _sort = 'takenAt,desc';
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
      appBar: AppBar(
        centerTitle: true,
        title: _TopToggle(
          isAlbums: _showAlbums,
          onChanged: (isAlbums) => setState(() => _showAlbums = isAlbums),
        ),
        actions: [
          if (_showAlbums)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '새 앨범',
              onPressed: () async {
                // 1) 사진 먼저 선택
                final selected = await Navigator.push<List<int>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SelectAlbumPhotosScreen(),
                  ),
                );
                if (!mounted) return;
                // 선택이 없으면 취소
                if (selected == null) return;

                // 2) 제목/설명 입력
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateAlbumScreenInitial(selectedPhotoIds: selected),
                  ),
                );
                if (!mounted) return;
                if (created != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('앨범이 생성되었습니다.')));
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            Expanded(
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
                                              mainAxisSpacing: 12,
                                              crossAxisSpacing: 12,
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
                                                        imageUrl: item.imageUrl,
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
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )),
                  if (!_showAlbums)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _FloatingSortButton(
                        sort: _sort,
                        onSortSelected: (v) {
                          setState(() => _sort = v);
                          context.read<PhotoProvider>().resetAndLoad(sort: v);
                        },
                      ),
                    ),
                ],
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
        errorBuilder: (context, error, stackTrace) => const _ThumbFallback(),
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
      );
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
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
    return const CircleAvatar(
      radius: 12,
      backgroundColor: Colors.redAccent,
      child: Icon(Icons.favorite, color: Colors.white, size: 14),
    );
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

class _AlbumListGrid extends StatelessWidget {
  const _AlbumListGrid();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlbumProvider>();
    if (provider.albums.isEmpty && !provider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
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
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: provider.albums.length,
        itemBuilder: (_, i) {
          final a = provider.albums[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlbumDetailScreen(albumId: a.albumId),
                        ),
                      );
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
                                  colors: [Colors.transparent, Colors.black26],
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

class _FloatingSortButton extends StatelessWidget {
  final String sort;
  final ValueChanged<String> onSortSelected;
  const _FloatingSortButton({required this.sort, required this.onSortSelected});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: IconButton(
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.sort_rounded, size: 18, color: Colors.white),
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) {
                  final isLatest = sort == 'takenAt,desc';
                  final isOldest = sort == 'takenAt,asc';
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          const Text(
                            '정렬 선택',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          CheckboxListTile(
                            title: const Text('최신순'),
                            value: isLatest,
                            onChanged: (v) {
                              onSortSelected('takenAt,desc');
                              Navigator.pop(context);
                            },
                          ),
                          CheckboxListTile(
                            title: const Text('오래된순'),
                            value: isOldest,
                            onChanged: (v) {
                              onSortSelected('takenAt,asc');
                              Navigator.pop(context);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            tooltip: '정렬',
          ),
        ),
      ),
    );
  }
}
