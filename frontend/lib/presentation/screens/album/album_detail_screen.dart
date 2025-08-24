import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/album_provider.dart';
import 'package:frontend/providers/photo_provider.dart';
import 'package:frontend/services/album_api.dart';
import 'select_album_photos_screen.dart';
// removed unused imports after refactor
import 'package:frontend/presentation/screens/photo/photo_viewer_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  final int albumId;
  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  bool _working = false;

  Future<void> _addPhotos() async {
    final selected = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(builder: (_) => const SelectAlbumPhotosScreen()),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() => _working = true);
    try {
      await AlbumApi.addPhotos(albumId: widget.albumId, photoIds: selected);
      if (!mounted) return;
      context.read<AlbumProvider>().addPhotos(widget.albumId, selected);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진이 추가되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('추가 실패: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _removeSelected(List<int> photoIds) async {
    if (photoIds.isEmpty) return;
    setState(() => _working = true);
    try {
      await AlbumApi.removePhotos(albumId: widget.albumId, photoIds: photoIds);
      if (!mounted) return;
      context.read<AlbumProvider>().removePhotos(widget.albumId, photoIds);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진이 삭제되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // _showPhotoActions (미사용) 제거

  @override
  Widget build(BuildContext context) {
    final albumProvider = context.watch<AlbumProvider>();
    final album = albumProvider.albums.firstWhere(
      (a) => a.albumId == widget.albumId,
      orElse: () => const AlbumItem(
        albumId: -1,
        title: '',
        description: '',
        coverPhotoUrl: null,
        photoCount: 0,
        createdAt: '',
        photoIdList: [],
      ),
    );
    if (album.albumId == -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AlbumProvider>().loadDetail(widget.albumId);
        }
      });
    }
    // 앨범은 있으나 상세(사진 목록)가 비어 있으면 상세 재요청
    final shouldFetchDetail = album.albumId != -1 && album.photoIdList.isEmpty;
    if (shouldFetchDetail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AlbumProvider>().loadDetail(widget.albumId);
        }
      });
    }
    final photos = context.watch<PhotoProvider>().items.where(
      (p) => album.photoIdList.contains(p.photoId),
    );
    final selected = <int>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(album.title.isEmpty ? '앨범' : album.title),
        actions: [
          IconButton(
            tooltip: '사진 선택',
            icon: const Icon(Icons.checklist_rtl),
            onPressed: () {
              // 길게 눌러 선택과 동일: 안내 토스트
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('사진을 길게 눌러 선택하세요.')));
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (v) async {
              switch (v) {
                case 'share':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('공유는 추후 지원 예정입니다.')),
                  );
                  break;
                case 'add':
                  if (!_working) await _addPhotos();
                  break;
                case 'edit':
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _AlbumEditSheet(albumId: widget.albumId),
                  );
                  break;
                case 'delete':
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('앨범 삭제'),
                      content: const Text('이 앨범을 삭제하시겠습니까?'),
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
                  if (ok == true) {
                    try {
                      final res = await AlbumApi.deleteAlbum(widget.albumId);
                      if (!mounted) return;
                      context.read<AlbumProvider>().removeAlbum(widget.albumId);
                      Navigator.pop(context); // 상세 화면 닫기
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            (res['message'] as String?) ?? '앨범이 삭제되었습니다.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                    }
                  }
                  break;
              }
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'share', child: Text('공유')),
              PopupMenuItem(value: 'add', child: Text('사진 추가')),
              PopupMenuItem(value: 'edit', child: Text('앨범 수정')),
              PopupMenuItem(value: 'delete', child: Text('앨범 삭제')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 앨범 상세에서는 상단 썸네일(커버) 노출 제거
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    album.description,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
                Text(
                  '총 ${album.photoCount}장',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // 태그 요약 영역 (모킹 기준)
          FutureBuilder<Map<String, dynamic>>(
            future: AlbumApi.getAlbum(widget.albumId),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final data = snap.data!;
              final List tags = (data['tagList'] as List? ?? []);
              if (tags.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: tags
                      .map(
                        (e) => Chip(
                          label: Text('#$e'),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList()
                      .cast<Widget>(),
                ),
              );
            },
          ),
          Expanded(
            child: shouldFetchDetail
                ? const Center(child: CircularProgressIndicator())
                : StatefulBuilder(
                    builder: (context, setInner) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: photos.length,
                        itemBuilder: (_, i) {
                          final p = photos.elementAt(i);
                          final isSel = selected.contains(p.photoId);
                          return GestureDetector(
                            onDoubleTap: () async {
                              try {
                                await AlbumApi.setCoverPhoto(
                                  albumId: widget.albumId,
                                  photoId: p.photoId,
                                );
                                if (!mounted) return;
                                context.read<AlbumProvider>().updateCoverUrl(
                                  widget.albumId,
                                  p.imageUrl,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('대표사진이 설정되었습니다.'),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('대표 설정 실패: $e')),
                                );
                              }
                            },
                            onLongPress: () {
                              setInner(() {
                                if (isSel) {
                                  selected.remove(p.photoId);
                                } else {
                                  selected.add(p.photoId);
                                }
                              });
                            },
                            onTap: () {
                              if (selected.isEmpty) {
                                // 전체화면 뷰어로 진입 (사진탭과 동일)
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PhotoViewerScreen(
                                      photoId: p.photoId,
                                      imageUrl: p.imageUrl,
                                      albumId: widget.albumId,
                                    ),
                                  ),
                                );
                              } else {
                                setInner(() {
                                  if (isSel) {
                                    selected.remove(p.photoId);
                                  } else {
                                    selected.add(p.photoId);
                                  }
                                });
                              }
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  p.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                        color: Color(0xFFE0E0E0),
                                      ),
                                ),
                                if (isSel)
                                  Container(
                                    color: Colors.blue.withOpacity(0.25),
                                  ),
                                // i 버튼 제거 요청에 따라 상세 오버레이 제거
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _working
                ? null
                : () async {
                    // 선택된 사진 삭제
                    final toRemove = selected.toList();
                    await _removeSelected(toRemove);
                  },
            icon: const Icon(Icons.delete_outline),
            label: const Text('선택 사진 삭제'),
          ),
        ),
      ),
    );
  }
}

class _AlbumEditSheet extends StatefulWidget {
  final int albumId;
  const _AlbumEditSheet({required this.albumId});

  @override
  State<_AlbumEditSheet> createState() => _AlbumEditSheetState();
}

class _AlbumEditSheetState extends State<_AlbumEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int? _coverId;
  String? _coverUrl;
  bool _submitting = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialized) return;
      final album = context.read<AlbumProvider>().byId(widget.albumId);
      if (album != null) {
        _titleCtrl.text = album.title;
        _descCtrl.text = album.description;
        _coverUrl ??= album.coverPhotoUrl;
      }
      _initialized = true;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, ctrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                controller: ctrl,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '앨범 수정',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final album = context.read<AlbumProvider>().byId(
                            widget.albumId,
                          );
                          if (album != null) {
                            if (_titleCtrl.text.isEmpty &&
                                album.title.isNotEmpty) {
                              _titleCtrl.text = album.title;
                            }
                            if (_descCtrl.text.isEmpty &&
                                album.description.isNotEmpty) {
                              _descCtrl.text = album.description;
                            }
                          }
                          final displayCover =
                              _coverUrl ?? album?.coverPhotoUrl;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  height: 180,
                                  width: double.infinity,
                                  child:
                                      (displayCover != null &&
                                          displayCover.isNotEmpty)
                                      ? Image.network(
                                          displayCover,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const ColoredBox(
                                                color: Color(0xFFE0E0E0),
                                              ),
                                        )
                                      : const ColoredBox(
                                          color: Color(0xFFE0E0E0),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) {
                                      final alb = context
                                          .read<AlbumProvider>()
                                          .byId(widget.albumId);
                                      final photos = context
                                          .read<PhotoProvider>()
                                          .items
                                          .where(
                                            (p) =>
                                                (alb?.photoIdList ?? const [])
                                                    .contains(p.photoId),
                                          )
                                          .toList();
                                      return SafeArea(
                                        child: SizedBox(
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.6,
                                          child: GridView.builder(
                                            padding: const EdgeInsets.all(12),
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 3,
                                                  mainAxisSpacing: 8,
                                                  crossAxisSpacing: 8,
                                                ),
                                            itemCount: photos.length,
                                            itemBuilder: (_, i) {
                                              final p = photos[i];
                                              return GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _coverId = p.photoId;
                                                    _coverUrl = p.imageUrl;
                                                  });
                                                  Navigator.pop(context);
                                                },
                                                child: Image.network(
                                                  p.imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const ColoredBox(
                                                        color: Color(
                                                          0xFFE0E0E0,
                                                        ),
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                icon: const Icon(Icons.image_outlined),
                                label: const Text('대표사진 수정'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(labelText: '제목'),
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(labelText: '설명'),
                        minLines: 1,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitting
                              ? null
                              : () async {
                                  setState(() => _submitting = true);
                                  try {
                                    await AlbumApi.updateAlbum(
                                      albumId: widget.albumId,
                                      title: _titleCtrl.text.trim().isEmpty
                                          ? null
                                          : _titleCtrl.text.trim(),
                                      description: _descCtrl.text.trim().isEmpty
                                          ? null
                                          : _descCtrl.text.trim(),
                                      coverPhotoId: _coverId,
                                    );
                                    if (!mounted) return;
                                    if (_titleCtrl.text.trim().isNotEmpty ||
                                        _descCtrl.text.trim().isNotEmpty) {
                                      // 간단히 닫고 상위에서 새로고침은 유지
                                    }
                                    if (_coverUrl != null) {
                                      context
                                          .read<AlbumProvider>()
                                          .updateCoverUrl(
                                            widget.albumId,
                                            _coverUrl,
                                          );
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('앨범 정보가 수정되었습니다.'),
                                      ),
                                    );
                                    Navigator.pop(context);
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('수정 실패: $e')),
                                    );
                                  } finally {
                                    if (mounted)
                                      setState(() => _submitting = false);
                                  }
                                },
                          icon: const Icon(Icons.check),
                          label: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('저장'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
