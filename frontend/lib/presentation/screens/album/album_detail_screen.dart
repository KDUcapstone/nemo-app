import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/album_provider.dart';
import 'package:frontend/providers/photo_provider.dart';
import 'package:frontend/services/album_api.dart';
import 'select_album_photos_screen.dart';
import 'package:frontend/services/friend_api.dart';
import 'package:flutter/services.dart';
// removed unused imports after refactor
import 'package:frontend/presentation/screens/photo/photo_viewer_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  final int albumId;
  final String? autoOpenAction; // 'edit' | 'share' 등 선택적 자동 실행 액션
  const AlbumDetailScreen({
    super.key,
    required this.albumId,
    this.autoOpenAction,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  bool _working = false;
  bool _autoHandled = false;
  bool _isSelectionMode = false;
  final Set<int> _selected = {};
  final ValueNotifier<Set<int>> _selectedNotifier = ValueNotifier<Set<int>>(
    <int>{},
  );
  // photos 캐싱 (해결책 A)
  List<PhotoItem>? _cachedPhotos;
  List<int>? _cachedPhotoIds;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 이후 자동 액션 실행 (모달/스낵바 등 UI 안전 호출)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _autoHandled) return;
      final action = widget.autoOpenAction;
      if (action == null) return;
      _autoHandled = true;
      if (action == 'edit') {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AlbumEditSheet(albumId: widget.albumId),
        );
      } else if (action == 'share') {
        await _showShareSheet(context);
      }
    });
  }

  @override
  void dispose() {
    _selectedNotifier.dispose();
    super.dispose();
  }

  // List 비교 헬퍼 함수 (해결책 A)
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

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

  Future<void> _showShareSheet(BuildContext context) async {
    final searchCtrl = TextEditingController();
    final selectedIds = <int>{};
    List<Map<String, dynamic>> friends = await FriendApi.getFriends();
    List<Map<String, dynamic>> shareTargets = [];
    try {
      shareTargets = await AlbumApi.getShareTargets(widget.albumId);
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
                                albumId: widget.albumId,
                                userId: s['userId'],
                              );
                              shareTargets.removeWhere(
                                (e) => e['userId'] == s['userId'],
                              );
                              (ctx as Element).markNeedsBuild();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('공유 해제되었습니다.')),
                              );
                            } catch (e) {
                              if (!mounted) return;
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
                      if (q.trim().isEmpty) {
                        friends = await FriendApi.getFriends();
                      } else {
                        final searchResults = await FriendApi.search(q);
                        friends = searchResults.where((f) {
                          final isFriend = (f['isFriend'] as bool?) ?? false;
                          return isFriend;
                        }).toList();
                      }
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
                      trailing: Checkbox(
                        value: checked,
                        onChanged: (v) {
                          if (v == true) {
                            selectedIds.add(id);
                          } else {
                            selectedIds.remove(id);
                          }
                          (ctx as Element).markNeedsBuild();
                        },
                      ),
                      onTap: () {
                        if (checked) {
                          selectedIds.remove(id);
                        } else {
                          selectedIds.add(id);
                        }
                        (ctx as Element).markNeedsBuild();
                      },
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
                                widget.albumId,
                                expiryHours: 48,
                                permission: 'view',
                              );
                              await Clipboard.setData(ClipboardData(text: url));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('공유 링크가 복사되었습니다.'),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
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
          albumId: widget.albumId,
          friendIdList: list,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(res['message'] ?? '공유 완료')));
      } catch (e) {
        if (!mounted) return;
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

    // PhotoProvider는 read로 변경하여 불필요한 rebuild 방지 (해결책 A)
    final photoProvider = context.read<PhotoProvider>();
    final albumPhotoIds = album.photoIdList;

    // 캐시 무효화 체크 (photoIdList가 변경된 경우만)
    if (_cachedPhotos == null || !_listEquals(_cachedPhotoIds, albumPhotoIds)) {
      _cachedPhotoIds = List.from(albumPhotoIds);
      _cachedPhotos = photoProvider.items
          .where((p) => albumPhotoIds.contains(p.photoId))
          .toList(); // List로 변환하여 O(1) 접근 보장
    }

    final photos = _cachedPhotos!;

    return Scaffold(
      appBar: AppBar(
        title: Text(album.title.isEmpty ? '앨범' : album.title),
        actions: [
          IconButton(
            tooltip: '사진 선택',
            icon: Icon(_isSelectionMode ? Icons.done : Icons.checklist_rtl),
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (!_isSelectionMode) {
                  _selected.clear(); // 선택 모드 해제 시 선택 항목 초기화
                  _selectedNotifier.value = <int>{};
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (v) async {
              switch (v) {
                case 'share':
                  await _showShareSheet(context);
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
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    cacheExtent: 500,
                    itemCount: photos.length,
                    itemBuilder: (_, i) {
                      final p = photos[i]; // elementAt → 인덱스 접근 (O(1))
                      final isSel = _selected.contains(p.photoId);
                      return RepaintBoundary(
                        child: _PhotoGridItem(
                          photo: p,
                          isSelectionMode: _isSelectionMode,
                          initialSelected: isSel,
                          onSelectionChanged: (photoId) {
                            // _selected Set만 업데이트 (부모 rebuild 완전 방지)
                            if (_selected.contains(photoId)) {
                              _selected.remove(photoId);
                            } else {
                              _selected.add(photoId);
                            }
                            // ValueNotifier 즉시 업데이트 (addPostFrameCallback 제거) (해결책 B)
                            _selectedNotifier.value = Set<int>.from(_selected);
                          },
                          onDoubleTap: () async {
                            if (_isSelectionMode) return;
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
                                const SnackBar(content: Text('대표사진이 설정되었습니다.')),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('대표 설정 실패: $e')),
                              );
                            }
                          },
                          onView: () {
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
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<Set<int>>(
        valueListenable: _selectedNotifier,
        builder: (context, selectedSet, _) {
          if (!_isSelectionMode || selectedSet.isEmpty) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: _working
                    ? null
                    : () async {
                        // 선택된 사진 삭제
                        final toRemove = selectedSet.toList();
                        await _removeSelected(toRemove);
                        setState(() {
                          _selected.clear();
                          _isSelectionMode = false;
                          _selectedNotifier.value = <int>{};
                        });
                      },
                icon: const Icon(Icons.delete_outline),
                label: Text('선택 사진 삭제 (${selectedSet.length})'),
              ),
            ),
          );
        },
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
                                    // 목록 카드 즉시 반영
                                    context.read<AlbumProvider>().updateMeta(
                                      albumId: widget.albumId,
                                      title: _titleCtrl.text.trim().isEmpty
                                          ? null
                                          : _titleCtrl.text.trim(),
                                      description: _descCtrl.text.trim().isEmpty
                                          ? null
                                          : _descCtrl.text.trim(),
                                    );
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

class _PhotoGridItem extends StatefulWidget {
  final PhotoItem photo;
  final bool isSelectionMode;
  final bool initialSelected;
  final ValueChanged<int> onSelectionChanged;
  final VoidCallback onDoubleTap;
  final VoidCallback onView;

  const _PhotoGridItem({
    required this.photo,
    required this.isSelectionMode,
    required this.initialSelected,
    required this.onSelectionChanged,
    required this.onDoubleTap,
    required this.onView,
  });

  @override
  State<_PhotoGridItem> createState() => _PhotoGridItemState();
}

class _PhotoGridItemState extends State<_PhotoGridItem> {
  final GlobalKey<_SelectionCheckboxState> _checkboxKey = GlobalKey();

  void _handleTap() {
    if (widget.isSelectionMode) {
      // 체크박스를 직접 토글하여 즉각적인 시각적 피드백 (부모 알림은 제외)
      _checkboxKey.currentState?.toggle(notifyParent: false);
      // 부모에게 알림 (비동기 처리)
      Future.microtask(() {
        widget.onSelectionChanged(widget.photo.photoId);
      });
    } else {
      widget.onView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.photo.imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            cacheWidth: 200,
            cacheHeight: 200,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return frame == null
                  ? const ColoredBox(color: Color(0xFFE0E0E0))
                  : child;
            },
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: Color(0xFFE0E0E0)),
          ),
          if (widget.isSelectionMode)
            Positioned(
              left: 6,
              top: 6,
              child: _SelectionCheckbox(
                key: _checkboxKey,
                initialSelected: widget.initialSelected,
                onChanged: () {
                  widget.onSelectionChanged(widget.photo.photoId);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectionCheckbox extends StatefulWidget {
  final bool initialSelected;
  final VoidCallback onChanged;

  const _SelectionCheckbox({
    super.key,
    required this.initialSelected,
    required this.onChanged,
  });

  @override
  State<_SelectionCheckbox> createState() => _SelectionCheckboxState();
}

class _SelectionCheckboxState extends State<_SelectionCheckbox> {
  late bool _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
  }

  @override
  void didUpdateWidget(_SelectionCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelected != widget.initialSelected) {
      _selected = widget.initialSelected;
    }
  }

  void toggle({bool notifyParent = false}) {
    // setState로 즉시 업데이트 (동기적, 가장 빠름)
    setState(() {
      _selected = !_selected;
    });
    // 부모에게 알림이 필요한 경우에만 호출
    if (notifyParent) {
      Future.microtask(() {
        widget.onChanged();
      });
    }
  }

  void _handleTap() {
    // 체크박스를 직접 터치한 경우에만 부모에게 알림
    toggle(notifyParent: true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _selected ? Colors.blue : Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _selected ? Icons.check : Icons.radio_button_unchecked,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}
