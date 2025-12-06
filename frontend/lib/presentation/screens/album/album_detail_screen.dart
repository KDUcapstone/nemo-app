import 'dart:io';
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
import 'package:frontend/presentation/screens/album/album_members_screen.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/services/photo_download_service.dart';
import 'package:image_picker/image_picker.dart';

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
  String? _myRole; // OWNER | CO_OWNER | EDITOR | VIEWER
  bool _roleLoading = false;
  bool _isSharedAlbum = false; // GET /api/albums/{id}의 shared 플래그
  bool _isLoadingDetail = false; // 무한 로딩 방지 플래그
  Future<Map<String, dynamic>>? _albumDetailFuture; // Future를 변수에 저장하여 무한 요청 방지
  bool _initialLoadTried = false; // 앨범 상세 최초 로딩 시도 여부

  @override
  void initState() {
    super.initState();
    // Future를 한 번만 생성하여 무한 요청 방지
    _albumDetailFuture = AlbumApi.getAlbum(widget.albumId);
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
    _loadMyRole();
  }

  // 앨범 상세 정보 새로고침 메서드
  void _refreshAlbumDetail() {
    setState(() {
      _albumDetailFuture = AlbumApi.getAlbum(widget.albumId);
    });
  }

  Future<void> _loadMyRole() async {
    setState(() => _roleLoading = true);
    try {
      // 공유 앨범이 아니면 내 개인 앨범으로 간주하여 OWNER 처리
      final albumProvider = context.read<AlbumProvider>();
      if (!albumProvider.isShared(widget.albumId)) {
        if (!mounted) return;
        setState(() {
          _myRole = 'OWNER';
          _roleLoading = false;
        });
        return;
      }
      // 공유 앨범인 경우, 우선 Provider에 저장된 내 역할을 사용
      final cachedRole = albumProvider.myRoleOf(widget.albumId);
      if (cachedRole != null && cachedRole.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _myRole = cachedRole.toUpperCase();
          _roleLoading = false;
        });
        return;
      }
      final me = context.read<UserProvider>().userId;
      final members = await AlbumApi.getShareMembers(widget.albumId);
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
      if (!mounted) return;
      setState(() {
        _myRole = role;
        _roleLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _myRole = null;
        _roleLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _selectedNotifier.dispose();
    super.dispose();
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
      // 앨범 상세 정보 새로고침
      _refreshAlbumDetail();
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
      // 앨범 상세 정보 새로고침
      _refreshAlbumDetail();
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
      // 이미 공유된 멤버 목록은 share/members API로 가져옴
      shareTargets = await AlbumApi.getShareMembers(widget.albumId);
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
                        // 친구가 아닌 사용자는 확실히 제외
                        friends = searchResults.where((f) {
                          final isFriend = (f['isFriend'] as bool?) ?? false;
                          return isFriend == true; // 명시적으로 true만 허용
                        }).toList();
                      }
                      // ignore: use_build_context_synchronously
                      (ctx as Element).markNeedsBuild();
                    },
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (_) {
                      // 이미 공유된 친구 ID 집합
                      final sharedUserIds = shareTargets
                          .map((s) => s['userId'] as int)
                          .toSet();
                      // 이미 공유된 친구를 제외한 친구 목록
                      final availableFriends = friends.where((f) {
                        final id = f['userId'] as int;
                        return !sharedUserIds.contains(id);
                      }).toList();

                      if (availableFriends.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              searchCtrl.text.trim().isEmpty
                                  ? '공유할 친구가 없습니다.'
                                  : '검색 결과가 없습니다.',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: List.generate(availableFriends.length, (idx) {
                          final f = availableFriends[idx];
                          final id = f['userId'] as int;
                          final nick = f['nickname'] as String? ?? '친구$id';
                          final avatarUrl =
                              (f['avatarUrl'] ?? f['profileImageUrl'])
                                  as String?;
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
                      );
                    },
                  ),
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
    if (raw.contains('NOT_FRIEND') || raw.contains('친구로 등록되지 않은')) {
      return '친구로 등록되지 않은 사용자가 포함되어 있습니다.';
    }
    if (raw.contains('이미 모두 공유된') || raw.contains('이미 공유된')) {
      return '이미 공유된 친구가 포함되어 있습니다.';
    }
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
    if (album.albumId == -1 && !_isLoadingDetail && !_initialLoadTried) {
      // 앨범 상세 최초 요청은 한 번만 수행 (에러 시 무한 재요청 방지)
      _isLoadingDetail = true;
      _initialLoadTried = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          try {
            await context.read<AlbumProvider>().loadDetail(widget.albumId);
          } finally {
            if (mounted) {
              setState(() {
                _isLoadingDetail = false;
              });
            }
          }
        }
      });
    }
    // 앨범은 있으나 상세(사진 목록)가 비어 있으면 상세 재요청 (무한 로딩 방지)
    // 단, photoCount가 0인 "빈 앨범"은 추가 호출 없이 그대로 처리
    final shouldFetchDetail =
        album.albumId != -1 &&
        album.photoIdList.isEmpty &&
        album.photoCount > 0 &&
        !_isLoadingDetail;
    if (shouldFetchDetail) {
      _isLoadingDetail = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          try {
            await context.read<AlbumProvider>().loadDetail(widget.albumId);
          } finally {
            if (mounted) {
              setState(() {
                _isLoadingDetail = false;
              });
            }
          }
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(album.title.isEmpty ? '앨범' : album.title),
        actions: [
          IconButton(
            tooltip: albumProvider.isFavorited(widget.albumId)
                ? '즐겨찾기 해제'
                : '즐겨찾기',
            icon: Icon(
              albumProvider.isFavorited(widget.albumId)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: albumProvider.isFavorited(widget.albumId)
                  ? Colors.red
                  : null,
            ),
            onPressed: () async {
              final current = albumProvider.isFavorited(widget.albumId);
              try {
                if (current) {
                  await AlbumApi.unfavoriteAlbum(widget.albumId);
                  if (!mounted) return;
                  albumProvider.setFavorite(widget.albumId, false);
                } else {
                  await AlbumApi.favoriteAlbum(widget.albumId);
                  if (!mounted) return;
                  albumProvider.setFavorite(widget.albumId, true);
                }
                // 즐겨찾기 상태 변경 후 리스트 새로고침하여 즉시 반영
                // favoriteOnly 필터가 켜져있을 때는 필수, 꺼져있을 때도 UI 업데이트를 위해 새로고침
                await albumProvider.resetAndLoad();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('처리 실패: $e')));
              }
            },
          ),
          // VIEWER도 멤버 조회와 다운로드 버튼을 볼 수 있어야 함
          if (!_roleLoading) _buildActionsMenu(context),
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
            future: _albumDetailFuture,
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
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshAlbumDetail();
                final f = _albumDetailFuture;
                if (f != null) {
                  await f;
                }
              },
              child: shouldFetchDetail
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<Map<String, dynamic>>(
                      future: _albumDetailFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          final error = snapshot.error;
                          print('❌ [AlbumDetailScreen] 에러: $error');
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '앨범을 불러오지 못했습니다',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  error.toString().replaceAll(
                                    'Exception: ',
                                    '',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    _refreshAlbumDetail();
                                  },
                                  child: const Text('다시 시도'),
                                ),
                              ],
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final data = snapshot.data!;
                        // 상세 응답의 shared 플래그를 지역 상태에 반영하여 AppBar 액션에 사용
                        final sharedFlag = data['shared'] as bool? ?? false;
                        if (sharedFlag != _isSharedAlbum) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _isSharedAlbum = sharedFlag;
                              });
                            }
                          });
                        }
                        final List photoListData =
                            (data['photoList'] as List? ?? []);

                        if (photoListData.isEmpty) {
                          // 사진이 0장일 때: "사진이 없습니다" 텍스트만 중앙에 표시 + 항상 당겨서 새로고침 가능
                          return ListView(
                            physics:
                                const AlwaysScrollableScrollPhysics(), // 항상 당겨서 새로고침 가능
                            children: const [
                              SizedBox(
                                height: 200,
                                child: Center(
                                  child: Text(
                                    '사진이 없습니다',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        // photoList를 PhotoItem으로 변환
                        final photos = photoListData.map((p) {
                          final photoData = p as Map<String, dynamic>;
                          return PhotoItem(
                            photoId: (photoData['photoId'] as num).toInt(),
                            imageUrl: photoData['imageUrl'] as String? ?? '',
                            takenAt: photoData['takenAt'] as String? ?? '',
                            location: photoData['location'] as String? ?? '',
                            brand: photoData['brand'] as String? ?? '',
                            tagList: const [], // 간단 요약용이므로 빈 리스트
                          );
                        }).toList();

                        return GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.9, // 세로가 조금 더 긴 직사각형 비율
                              ),
                          cacheExtent: 500,
                          itemCount: photos.length,
                          itemBuilder: (_, i) {
                            final p = photos[i];
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
                                  // ValueNotifier 즉시 업데이트
                                  _selectedNotifier.value = Set<int>.from(
                                    _selected,
                                  );
                                },
                                onDoubleTap: () async {
                                  if (_isSelectionMode) return;
                                  try {
                                    final res = await AlbumApi.setThumbnail(
                                      albumId: widget.albumId,
                                      photoId: p.photoId,
                                    );
                                    if (!mounted) return;
                                    final newUrl =
                                        (res['thumbnailUrl'] as String?) ??
                                        p.imageUrl;
                                    context
                                        .read<AlbumProvider>()
                                        .updateCoverUrl(widget.albumId, newUrl);
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
                        );
                      },
                    ),
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
          // 사진 삭제 권한: OWNER, CO_OWNER, EDITOR만 가능
          final role = _myRole ?? 'VIEWER';
          final canDeletePhotos =
              role == 'OWNER' || role == 'CO_OWNER' || role == 'EDITOR';

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _working
                          ? null
                          : () async {
                              try {
                                final ids = selectedSet.toList();
                                final count =
                                    await PhotoDownloadService.downloadPhotosToGallery(
                                      ids,
                                    );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                      bottom: 32,
                                    ),
                                    content: Text(
                                      count > 0
                                          ? '$count장의 사진을 갤러리에 저장했어요.'
                                          : '다운로드 가능한 사진이 없습니다.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                      bottom: 32,
                                    ),
                                    content: Text('다운로드 중 오류가 발생했습니다: $e'),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        '선택 다운로드 (${selectedSet.length})',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  if (canDeletePhotos) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
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
                        label: Text('선택 삭제 (${selectedSet.length})'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionsMenu(BuildContext context) {
    final albumProvider = context.read<AlbumProvider>();
    // Provider 상태와 상세 응답 플래그를 모두 고려 (둘 중 하나라도 true면 공유 앨범으로 간주)
    final isAlbumShared =
        _isSharedAlbum || albumProvider.isShared(widget.albumId);
    // 역할별 허용 액션 계산
    final role = _myRole ?? 'VIEWER';
    final isOwner = role == 'OWNER';
    final isCoOwner = role == 'CO_OWNER';
    final isEditor = role == 'EDITOR';

    // 공유: OWNER와 CO_OWNER만 가능
    final showShare = isOwner || isCoOwner;
    // 사진 추가: OWNER, CO_OWNER, EDITOR 가능
    final showAdd = isOwner || isCoOwner || isEditor;
    // 앨범 수정: OWNER만 가능 (CO_OWNER, EDITOR 불가)
    final showEdit = isOwner;
    // 삭제: OWNER만 가능
    final showDelete = isOwner;
    // 멤버 조회: 실제로 공유된 앨범에서만 노출 (shared == true)
    final showMembers = isAlbumShared;
    // 앨범 나가기: OWNER가 아닌 공유 앨범 멤버만 가능
    final showLeave = isAlbumShared && !isOwner;
    return Row(
      children: [
        IconButton(
          tooltip: '사진 선택',
          icon: Icon(_isSelectionMode ? Icons.done : Icons.checklist_rtl),
          onPressed: () {
            setState(() {
              _isSelectionMode = !_isSelectionMode;
              if (!_isSelectionMode) {
                _selected.clear();
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
              case 'download_all':
                try {
                  final count =
                      await PhotoDownloadService.downloadAlbumToGallery(
                        widget.albumId,
                      );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 32,
                      ),
                      content: Text(
                        count > 0
                            ? '$count장의 사진을 갤러리에 저장했어요.'
                            : '다운로드 가능한 사진이 없습니다.',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 32,
                      ),
                      content: Text('다운로드 중 오류가 발생했습니다: $e'),
                    ),
                  );
                }
                break;
              case 'members':
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlbumMembersScreen(albumId: widget.albumId),
                  ),
                );
                // 멤버 화면에서 돌아온 후 role 재로드 (권한 변경 반영)
                if (mounted) {
                  await _loadMyRole();
                }
                break;
              case 'leave':
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('앨범 나가기'),
                    content: const Text('정말 추억을 접어두시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('나가기'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  try {
                    final currentUserId = context.read<UserProvider>().userId;
                    if (currentUserId == null) {
                      throw Exception('사용자 정보를 찾을 수 없습니다.');
                    }
                    await AlbumApi.removeShareMember(
                      albumId: widget.albumId,
                      targetUserId: currentUserId,
                    );
                    if (!mounted) return;
                    // 앨범 목록에서 제거
                    context.read<AlbumProvider>().removeAlbum(widget.albumId);
                    // 앨범 상세 화면 닫고 이전 화면으로
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('앨범에서 나갔습니다.')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    final errorMsg = e.toString();
                    String message;
                    if (errorMsg.contains('CANNOT_REMOVE_OWNER')) {
                      message = '소유자는 앨범에서 나갈 수 없습니다.';
                    } else if (errorMsg.contains('FORBIDDEN')) {
                      message = '권한이 없습니다.';
                    } else {
                      message = '나가기 실패: $e';
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                }
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
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          (res['message'] as String?) ?? '앨범이 삭제되었습니다.',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    final errorMsg = e.toString();
                    String message;
                    if (errorMsg.contains('FORBIDDEN') ||
                        errorMsg.contains('권한이 없습니다') ||
                        errorMsg.contains('삭제할 권한') ||
                        errorMsg.contains('공유받은 앨범')) {
                      message = '공유받은 앨범은 삭제할 수 없습니다.';
                    } else if (errorMsg.contains('ALBUM_NOT_FOUND')) {
                      message = '앨범을 찾을 수 없습니다.';
                    } else {
                      message = '삭제 실패: $e';
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                }
                break;
            }
          },
          itemBuilder: (c) => [
            if (showShare)
              const PopupMenuItem(value: 'share', child: Text('공유')),
            if (showAdd)
              const PopupMenuItem(value: 'add', child: Text('사진 추가')),
            if (showEdit)
              const PopupMenuItem(value: 'edit', child: Text('앨범 수정')),
            // 전체 다운로드는 VIEWER 이상 멤버 모두 허용 (백엔드에서 권한 검증)
            const PopupMenuItem(value: 'download_all', child: Text('전체 다운로드')),
            if (showMembers)
              const PopupMenuItem(value: 'members', child: Text('멤버 조회')),
            if (showLeave)
              const PopupMenuItem(value: 'leave', child: Text('앨범 나가기')),
            if (showDelete)
              const PopupMenuItem(value: 'delete', child: Text('앨범 삭제')),
          ],
        ),
      ],
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
  File? _coverFile; // 파일 업로드용
  bool _submitting = false;
  bool _initialized = false;
  final ImagePicker _imagePicker = ImagePicker();

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
                                  child: _coverFile != null
                                      ? Image.file(
                                          _coverFile!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const ColoredBox(
                                                color: Color(0xFFE0E0E0),
                                              ),
                                        )
                                      : (displayCover != null &&
                                            displayCover.isNotEmpty)
                                      ? (displayCover.startsWith('http')
                                            ? Image.network(
                                                displayCover,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const ColoredBox(
                                                      color: Color(0xFFE0E0E0),
                                                    ),
                                              )
                                            : Image.file(
                                                File(displayCover),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const ColoredBox(
                                                      color: Color(0xFFE0E0E0),
                                                    ),
                                              ))
                                      : const ColoredBox(
                                          color: Color(0xFFE0E0E0),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  // 선택지 제공: 앨범 내 사진 선택 또는 파일 업로드
                                  final choice =
                                      await showModalBottomSheet<String>(
                                        context: context,
                                        builder: (_) => SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.photo_library,
                                                ),
                                                title: const Text('앨범 내 사진 선택'),
                                                onTap: () => Navigator.pop(
                                                  context,
                                                  'gallery',
                                                ),
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.upload_file,
                                                ),
                                                title: const Text('파일 업로드'),
                                                onTap: () => Navigator.pop(
                                                  context,
                                                  'upload',
                                                ),
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.cancel,
                                                ),
                                                title: const Text('취소'),
                                                onTap: () =>
                                                    Navigator.pop(context),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );

                                  if (choice == 'gallery') {
                                    // 앨범 내 사진 선택
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
                                                    childAspectRatio:
                                                        0.9, // 세로가 조금 더 긴 직사각형 비율
                                                  ),
                                              itemCount: photos.length,
                                              itemBuilder: (_, i) {
                                                final p = photos[i];
                                                return GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _coverId = p.photoId;
                                                      _coverUrl = p.imageUrl;
                                                      _coverFile =
                                                          null; // 파일 선택 취소
                                                    });
                                                    Navigator.pop(context);
                                                  },
                                                  child: Image.network(
                                                    p.imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
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
                                  } else if (choice == 'upload') {
                                    // 파일 업로드
                                    final XFile? image = await _imagePicker
                                        .pickImage(source: ImageSource.gallery);
                                    if (image != null && mounted) {
                                      setState(() {
                                        _coverFile = File(image.path);
                                        _coverId = null; // 사진 선택 취소
                                        _coverUrl = image.path; // 미리보기용
                                      });
                                    }
                                  }
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
                                    // 제목/설명 수정 (대표사진 제외)
                                    await AlbumApi.updateAlbum(
                                      albumId: widget.albumId,
                                      title: _titleCtrl.text.trim().isEmpty
                                          ? null
                                          : _titleCtrl.text.trim(),
                                      description: _descCtrl.text.trim().isEmpty
                                          ? null
                                          : _descCtrl.text.trim(),
                                      // coverPhotoId 제거 - 대표사진은 별도 API 사용
                                    );

                                    // 대표사진 수정 (명세서에 따른 별도 API 호출)
                                    if (_coverFile != null) {
                                      // 파일 업로드 방식
                                      final thumbnailRes =
                                          await AlbumApi.uploadThumbnailFile(
                                            albumId: widget.albumId,
                                            file: _coverFile!,
                                          );

                                      // 응답에서 thumbnailUrl 가져오기
                                      final thumbnailUrl =
                                          thumbnailRes['thumbnailUrl']
                                              as String?;
                                      if (thumbnailUrl != null) {
                                        context
                                            .read<AlbumProvider>()
                                            .updateCoverUrl(
                                              widget.albumId,
                                              thumbnailUrl,
                                            );
                                      }
                                    } else if (_coverId != null) {
                                      // 앨범 내 사진 선택 방식
                                      final thumbnailRes =
                                          await AlbumApi.setThumbnail(
                                            albumId: widget.albumId,
                                            photoId: _coverId,
                                          );

                                      // 응답에서 thumbnailUrl 가져오기
                                      final thumbnailUrl =
                                          thumbnailRes['thumbnailUrl']
                                              as String?;
                                      if (thumbnailUrl != null) {
                                        context
                                            .read<AlbumProvider>()
                                            .updateCoverUrl(
                                              widget.albumId,
                                              thumbnailUrl,
                                            );
                                      }
                                    }

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

                                    // 앨범 목록 새로고침 (다른 화면 반영)
                                    await context
                                        .read<AlbumProvider>()
                                        .resetAndLoad();

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
            fit: BoxFit.cover, // 셀을 꽉 채우도록 변경
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
