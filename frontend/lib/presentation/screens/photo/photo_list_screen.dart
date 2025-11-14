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
import 'package:frontend/services/friend_api.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:flutter/services.dart';

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: !_showAlbums
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 70,
                                  ),
                                  child: _BrandFilter(
                                    value: _brand,
                                    onChanged: (v) {
                                      setState(() => _brand = v);
                                      context
                                          .read<PhotoProvider>()
                                          .resetAndLoad(brand: v);
                                    },
                                  ),
                                )
                              : const SizedBox(width: 40),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: _TopToggle(
                            isAlbums: _showAlbums,
                            onChanged: (isAlbums) =>
                                setState(() => _showAlbums = isAlbums),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _showAlbums
                              ? IconButton(
                                  icon: const Icon(Icons.add),
                                  tooltip: '새 앨범',
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  onPressed: () async {
                                    final selected =
                                        await Navigator.push<List<int>>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SelectAlbumPhotosScreen(),
                                          ),
                                        );
                                    if (!mounted) return;
                                    if (selected == null) return;

                                    final created = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CreateAlbumScreenInitial(
                                              selectedPhotoIds: selected,
                                            ),
                                      ),
                                    );
                                    if (!mounted) return;
                                    if (created != null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('앨범이 생성되었습니다.'),
                                        ),
                                      );
                                    }
                                  },
                                )
                              : ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 30,
                                  ),
                                  child: _SortDropdown(
                                    value: _sort,
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() => _sort = v);
                                      context
                                          .read<PhotoProvider>()
                                          .resetAndLoad(sort: v);
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
      borderRadius: BorderRadius.circular(18),
      constraints: const BoxConstraints(minHeight: 32, minWidth: 80),
      selectedColor: scheme.onPrimary,
      fillColor: scheme.primary,
      color: scheme.onSurface.withOpacity(0.8),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('사진'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
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
    final dropdownValue = brands.contains(value) ? value : null;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        border: Border.all(color: AppColors.divider, width: 1),
        borderRadius: BorderRadius.circular(1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: dropdownValue,
          isExpanded: true,
          hint: const Text(
            '🏷️',
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          icon: const Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: AppColors.textPrimary,
          ),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          onChanged: (selected) {
            debugPrint('[BrandFilter] dropdown changed value=$selected');
            onChanged(selected);
          },
          selectedItemBuilder: (ctx) => brands
              .map(
                (_) => const Center(
                  child: Text(
                    '🏷️',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          items: brands
              .map(
                (b) => DropdownMenuItem<String?>(
                  value: b,
                  child: Text(
                    b ?? '전체',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
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
                        if (action == 'share') {
                          // AlbumDetailScreen으로 이동하지 않고 바로 공유 시트 표시
                          await _showAlbumShareSheet(context, a.albumId);
                        } else if (action == 'edit') {
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

  // 공유 시트 함수 (album_detail_screen.dart의 _showShareSheet와 동일)
  Future<void> _showAlbumShareSheet(BuildContext context, int albumId) async {
    final searchCtrl = TextEditingController();
    final selectedIds = <int>{};
    final Set<int> inFlight = <int>{};
    List<Map<String, dynamic>> friends = await FriendApi.list();
    List<Map<String, dynamic>> shareTargets = [];
    try {
      shareTargets = await AlbumApi.getShareTargets(albumId);
    } catch (_) {}
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '앨범 공유',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  if (shareTargets.isNotEmpty) ...[
                    const Text(
                      '현재 공유 대상',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...shareTargets.map(
                      (s) => ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(
                          s['nickname'] ?? 'user${s['userId'] ?? ''}',
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            try {
                              await AlbumApi.unshareTarget(
                                albumId: albumId,
                                userId: s['userId'],
                              );
                              shareTargets.removeWhere(
                                (e) => e['userId'] == s['userId'],
                              );
                              (ctx as Element).markNeedsBuild();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('공유 해제되었습니다.')),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('공유 해제 실패: $e')),
                              );
                            }
                          },
                          child: const Text('제거'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: '친구 검색 (닉네임/이메일)',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (q) async {
                      friends = q.trim().isEmpty
                          ? await FriendApi.list()
                          : await FriendApi.search(q);
                      // ignore: use_build_context_synchronously
                      (ctx as Element).markNeedsBuild();
                    },
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(friends.length, (idx) {
                    final f = friends[idx];
                    final id = f['userId'] as int;
                    final nick = f['nickname'] as String? ?? '친구$id';
                    final avatarUrl =
                        (f['avatarUrl'] ?? f['profileImageUrl']) as String?;
                    final isFriend = (f['isFriend'] as bool?) ?? true;
                    final checked = selectedIds.contains(id);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      title: Text(nick),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isFriend)
                            OutlinedButton(
                              onPressed: inFlight.contains(id)
                                  ? null
                                  : () async {
                                      inFlight.add(id);
                                      (ctx as Element).markNeedsBuild();
                                      try {
                                        await FriendApi.addFriend(id);
                                        friends[idx] = {...f, 'isFriend': true};
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('친구 추가 완료: $nick'),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        final msg =
                                            e.toString().contains(
                                              'ALREADY_FRIEND',
                                            )
                                            ? '이미 친구입니다.'
                                            : e.toString().contains(
                                                'USER_NOT_FOUND',
                                              )
                                            ? '사용자를 찾을 수 없습니다.'
                                            : '친구 추가 실패';
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(msg)),
                                        );
                                      } finally {
                                        inFlight.remove(id);
                                        (ctx).markNeedsBuild();
                                      }
                                    },
                              child: inFlight.contains(id)
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('친구 추가'),
                            ),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: checked,
                            onChanged: isFriend
                                ? (v) {
                                    if (v == true) {
                                      selectedIds.add(id);
                                    } else {
                                      selectedIds.remove(id);
                                    }
                                    (ctx as Element).markNeedsBuild();
                                  }
                                : null,
                          ),
                        ],
                      ),
                      onTap: isFriend
                          ? () {
                              if (checked) {
                                selectedIds.remove(id);
                              } else {
                                selectedIds.add(id);
                              }
                              (ctx as Element).markNeedsBuild();
                            }
                          : null,
                    );
                  }),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final url = await AlbumApi.createShareLink(
                                albumId,
                                expiryHours: 48,
                                permission: 'view',
                              );
                              await Clipboard.setData(ClipboardData(text: url));
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('공유 링크가 복사되었습니다.'),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('링크 생성 실패: $e')),
                              );
                            }
                          },
                          icon: const Icon(Icons.link),
                          label: const Text('링크 생성/복사'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () => Navigator.pop(ctx, selectedIds.toList()),
                          icon: const Icon(Icons.check),
                          label: Text('${selectedIds.length}명에게 공유'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((value) async {
      final list = (value as List<int>?) ?? [];
      if (list.isEmpty) return;
      try {
        final res = await AlbumApi.shareAlbum(
          albumId: albumId,
          friendIdList: list,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(res['message'] ?? '공유 완료')));
      } catch (e) {
        if (!context.mounted) return;
        final msg = _mapShareError(e.toString());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    });
  }

  String _mapShareError(String raw) {
    if (raw.contains('NOT_FRIEND')) return '친구로 등록되지 않은 사용자가 포함되어 있습니다.';
    if (raw.contains('FORBIDDEN')) return '이 앨범을 공유할 권한이 없습니다.';
    if (raw.contains('ALBUM_NOT_FOUND')) return '앨범을 찾을 수 없습니다.';
    return '공유 중 오류가 발생했습니다.';
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
