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
import 'package:frontend/services/photo_download_service.dart';

class PhotoViewerScreen extends StatefulWidget {
  final int photoId;
  final String imageUrl;
  final int? albumId; // 앨범에서 진입 시 앨범 ID 전달
  final List<PhotoItem>? photos; // 사진 목록 (슬라이딩용)
  final int? initialIndex; // 초기 인덱스 (슬라이딩용)

  const PhotoViewerScreen({
    super.key,
    required this.photoId,
    required this.imageUrl,
    this.albumId,
    this.photos,
    this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  bool _showUI = true;
  String? _myRole; // 앨범에서 진입한 경우 내 role 저장
  late PageController _pageController;
  late int _currentIndex;
  late List<PhotoItem> _photos;

  @override
  void initState() {
    super.initState();

    // 사진 목록 초기화
    if (widget.photos != null && widget.photos!.isNotEmpty) {
      _photos = widget.photos!;
      _currentIndex =
          widget.initialIndex ??
          _photos.indexWhere((p) => p.photoId == widget.photoId);
      if (_currentIndex == -1) _currentIndex = 0;
    } else {
      // 사진 목록이 없으면 현재 사진만 포함
      _photos = [
        PhotoItem(
          photoId: widget.photoId,
          imageUrl: widget.imageUrl,
          takenAt: '',
          location: '',
          brand: '',
          tagList: [],
        ),
      ];
      _currentIndex = 0;
    }

    _pageController = PageController(initialPage: _currentIndex);

    // 앨범에서 진입한 경우 role 확인
    if (widget.albumId != null) {
      _loadMyRole();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // 현재 표시 중인 사진 정보
  PhotoItem get _currentPhoto => _photos[_currentIndex];
  int get _currentPhotoId => _currentPhoto.photoId;
  String get _currentImageUrl => _currentPhoto.imageUrl;

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
    // 앨범에서 진입한 경우: OWNER, CO_OWNER, EDITOR는 사진 삭제 가능
    return _myRole == 'OWNER' || _myRole == 'CO_OWNER' || _myRole == 'EDITOR';
  }

  Widget _buildImage(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    final isFile = uri == null || !uri.hasScheme;
    return isFile
        ? Image.file(File(imageUrl), fit: BoxFit.contain)
        : Image.network(imageUrl, fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) {
    final isFav = context.select<PhotoProvider, bool>((p) {
      final idx = p.items.indexWhere((e) => e.photoId == _currentPhotoId);
      return idx != -1 ? p.items[idx].favorite : false;
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // PageView로 사진 슬라이딩
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  return GestureDetector(
                    onTap: _toggleUI,
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Center(child: _buildImage(photo.imageUrl)),
                    ),
                  );
                },
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
                      builder: (_) =>
                          DetailSheetModal(photoId: _currentPhotoId),
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
                                    _currentPhotoId,
                                  );
                                  if (!context.mounted) return;
                                  // API 명세서: { photoId, isFavorite, message }
                                  final isFavorite =
                                      response['isFavorite'] as bool? ?? false;
                                  context
                                      .read<PhotoProvider>()
                                      .updateFromResponse({
                                        'photoId': _currentPhotoId,
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
                                        photoId: _currentPhotoId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            // 단일 사진 다운로드 버튼
                            IconButton(
                              tooltip: '다운로드',
                              icon: const Icon(
                                Icons.download_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () async {
                                try {
                                  final success =
                                      await PhotoDownloadService.downloadSinglePhotoToGallery(
                                        _currentPhotoId,
                                      );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? '사진을 갤러리에 저장했어요.'
                                            : '다운로드에 실패했습니다.',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('다운로드 중 오류가 발생했습니다: $e'),
                                    ),
                                  );
                                }
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
                                        photoIds: [_currentPhotoId],
                                      );
                                      if (!context.mounted) return;
                                      // 앨범 상태만 수정
                                      // ignore: use_build_context_synchronously
                                      context
                                          .read<AlbumProvider>()
                                          .removePhotos(widget.albumId!, [
                                            _currentPhotoId,
                                          ]);
                                    } else {
                                      final api = PhotoApi();
                                      await api.deletePhoto(_currentPhotoId);
                                      if (!context.mounted) return;
                                      context.read<PhotoProvider>().removeById(
                                        _currentPhotoId,
                                      );

                                      // 삭제된 사진이 썸네일인 앨범들을 찾아서 자동으로 썸네일 변경
                                      if (_currentImageUrl.isNotEmpty) {
                                        final albumProvider = context
                                            .read<AlbumProvider>();
                                        final albums = albumProvider.albums;
                                        for (final album in albums) {
                                          // 앨범의 썸네일 URL이 삭제된 사진의 imageUrl과 일치하는지 확인
                                          if (album.coverPhotoUrl ==
                                              _currentImageUrl) {
                                            try {
                                              // 자동으로 앨범 내 다른 사진으로 썸네일 변경
                                              final res =
                                                  await AlbumApi.setThumbnail(
                                                    albumId: album.albumId,
                                                    photoId:
                                                        null, // null이면 자동으로 최신 사진 선택
                                                  );
                                              // 썸네일 URL 업데이트
                                              if (res['thumbnailUrl'] != null) {
                                                albumProvider.updateCoverUrl(
                                                  album.albumId,
                                                  res['thumbnailUrl']
                                                      as String?,
                                                );
                                              }
                                            } catch (e) {
                                              debugPrint(
                                                '⚠️ 앨범 썸네일 자동 변경 실패 (albumId: ${album.albumId}): $e',
                                              );
                                            }
                                          }
                                        }
                                      }
                                    }
                                    // 삭제된 사진이 마지막 사진이면 이전 사진으로 이동
                                    if (_photos.length > 1) {
                                      if (_currentIndex >= _photos.length - 1) {
                                        // 마지막 사진이면 이전으로
                                        _pageController.previousPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      } else {
                                        // 다음 사진으로 이동
                                        _pageController.nextPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                      _photos.removeAt(_currentIndex);
                                      setState(() {
                                        if (_currentIndex >= _photos.length) {
                                          _currentIndex = _photos.length - 1;
                                        }
                                      });
                                    } else {
                                      // 마지막 사진이면 화면 닫기
                                      Navigator.pop(context);
                                    }
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            widget.albumId != null
                                                ? '앨범에서 제거했습니다.'
                                                : '사진이 성공적으로 삭제되었습니다.',
                                          ),
                                        ),
                                      );
                                    }
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
