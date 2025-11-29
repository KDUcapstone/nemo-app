import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/photo_provider.dart';
import 'photo_viewer_screen.dart';
import 'package:frontend/presentation/screens/album/create_album_screen.dart';
import 'package:frontend/presentation/screens/album/select_album_photos_screen.dart';
import 'package:frontend/presentation/screens/album/album_detail_screen.dart';
import 'package:frontend/services/album_api.dart';
import 'package:frontend/services/friend_api.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/presentation/screens/photo/photo_add_detail_screen.dart';
import 'package:frontend/presentation/screens/notification/notification_bottom_sheet.dart';
import 'package:frontend/widgets/notification_badge_icon.dart';
import 'package:frontend/services/photo_download_service.dart';
import 'package:frontend/providers/album_provider.dart';

class PhotoListScreen extends StatefulWidget {
  const PhotoListScreen({super.key});

  @override
  State<PhotoListScreen> createState() => _PhotoListScreenState();
}

class _PhotoListScreenState extends State<PhotoListScreen> {
  bool _showAlbums = false;
  String _sort = 'takenAt,desc';
  String _albumSort = 'createdAt,desc';
  bool _albumSharedOnly = false;
  String? _brand;
  final ImagePicker _imagePicker = ImagePicker();
  // 앨범 목록 새로고침을 위한 GlobalKey
  final GlobalKey<_AlbumListGridState> _albumListGridKey =
      GlobalKey<_AlbumListGridState>();
  // 사진 탭 선택 다운로드용 상태
  bool _photoSelectionMode = false;
  final Set<int> _selectedPhotoIds = <int>{};
  bool _photoDownloadWorking = false;

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

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        final file = File(image.path);
        // PhotoAddDetailScreen으로 이동 (qrCode: null)
        final success = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoAddDetailScreen(
              imageFile: file,
              qrCode: null, // QR 없음
              defaultTakenAt: null, // EXIF 또는 사용자 입력
            ),
          ),
        );
        if (success == true && mounted) {
          // 사진이 성공적으로 추가된 경우 (화면에서 이미 알림 표시)
          // Provider 상태는 PhotoAddDetailScreen에서 이미 업데이트됨
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('갤러리에서 사진을 선택하지 못했습니다: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<PhotoProvider>().items;
    return Scaffold(
      appBar: null,
      // 사진 선택 모드일 때는 갤러리 추가 FAB 숨기기
      floatingActionButton: (!_showAlbums && !_photoSelectionMode)
          ? _GlassFloatingActionButton(onPressed: _pickFromGallery)
          : null,
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
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 30),
                            child: _showAlbums
                                ? _AlbumSortDropdown(
                                    value: _albumSort,
                                    sharedOnly: _albumSharedOnly,
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() => _albumSort = v);
                                    },
                                    onToggleSharedOnly: (v) {
                                      setState(() => _albumSharedOnly = v);
                                    },
                                  )
                                : _SortDropdown(
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
                        Align(
                          alignment: Alignment.center,
                          child: _TopToggle(
                            isAlbums: _showAlbums,
                            onChanged: (isAlbums) {
                              setState(() {
                                _showAlbums = isAlbums;
                                if (isAlbums) {
                                  // 앨범 탭으로 전환 시 사진 선택 상태 리셋
                                  _photoSelectionMode = false;
                                  _selectedPhotoIds.clear();
                                  _photoDownloadWorking = false;
                                }
                              });
                            },
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
                                      // 앨범 생성 후 목록 새로고침
                                      _albumListGridKey.currentState?.refresh();
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
                    // 사진 탭일 때만 items.isEmpty 체크, 앨범 탭일 때는 항상 앨범 목록 표시
                    (!_showAlbums && items.isEmpty)
                        ? const _EmptyState()
                        : (_showAlbums
                              ? _AlbumListGrid(
                                  key: _albumListGridKey,
                                  sort: _albumSort,
                                  sharedOnly: _albumSharedOnly,
                                )
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
                                              isSelectionMode:
                                                  _photoSelectionMode,
                                              isSelected: _selectedPhotoIds
                                                  .contains(item.photoId),
                                              onTap: () {
                                                if (_photoSelectionMode) {
                                                  setState(() {
                                                    if (_selectedPhotoIds
                                                        .contains(
                                                          item.photoId,
                                                        )) {
                                                      _selectedPhotoIds.remove(
                                                        item.photoId,
                                                      );
                                                      if (_selectedPhotoIds
                                                          .isEmpty) {
                                                        _photoSelectionMode =
                                                            false;
                                                      }
                                                    } else {
                                                      _selectedPhotoIds.add(
                                                        item.photoId,
                                                      );
                                                    }
                                                  });
                                                } else {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          PhotoViewerScreen(
                                                            photoId:
                                                                item.photoId,
                                                            imageUrl:
                                                                item.imageUrl,
                                                          ),
                                                    ),
                                                  );
                                                }
                                              },
                                              onLongPress: () {
                                                setState(() {
                                                  _photoSelectionMode = true;
                                                  _selectedPhotoIds.add(
                                                    item.photoId,
                                                  );
                                                });
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
                                        if (_photoSelectionMode &&
                                            _selectedPhotoIds.isNotEmpty)
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            child: SafeArea(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Row(
                                                  children: [
                                                    TextButton(
                                                      onPressed:
                                                          _photoDownloadWorking
                                                          ? null
                                                          : () {
                                                              setState(() {
                                                                _photoSelectionMode =
                                                                    false;
                                                                _selectedPhotoIds
                                                                    .clear();
                                                              });
                                                            },
                                                      child: const Text('취소'),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: ElevatedButton.icon(
                                                        onPressed:
                                                            _photoDownloadWorking
                                                            ? null
                                                            : () async {
                                                                setState(() {
                                                                  _photoDownloadWorking =
                                                                      true;
                                                                });
                                                                try {
                                                                  final count =
                                                                      await PhotoDownloadService.downloadPhotosToGallery(
                                                                        _selectedPhotoIds
                                                                            .toList(),
                                                                      );
                                                                  if (!mounted) {
                                                                    return;
                                                                  }
                                                                  ScaffoldMessenger.of(
                                                                    context,
                                                                  ).showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(
                                                                        count > 0
                                                                            ? '$count개의 사진을 갤러리에 저장했어요.'
                                                                            : '다운로드 가능한 사진이 없습니다.',
                                                                      ),
                                                                    ),
                                                                  );
                                                                  setState(() {
                                                                    _photoSelectionMode =
                                                                        false;
                                                                    _selectedPhotoIds
                                                                        .clear();
                                                                  });
                                                                } catch (e) {
                                                                  if (!mounted) {
                                                                    return;
                                                                  }
                                                                  ScaffoldMessenger.of(
                                                                    context,
                                                                  ).showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(
                                                                        '다운로드 중 오류: $e',
                                                                      ),
                                                                    ),
                                                                  );
                                                                } finally {
                                                                  if (mounted) {
                                                                    setState(() {
                                                                      _photoDownloadWorking =
                                                                          false;
                                                                    });
                                                                  }
                                                                }
                                                              },
                                                        icon: const Icon(
                                                          Icons
                                                              .download_rounded,
                                                        ),
                                                        label: Text(
                                                          '선택 다운로드 (${_selectedPhotoIds.length})',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
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
            NotificationBadgeIcon(
              icon: Icons.notifications_none_rounded,
              color: AppColors.textPrimary,
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const NotificationBottomSheet(),
                );
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

class _AlbumSortDropdown extends StatelessWidget {
  final String
  value; // 'createdAt,desc' | 'createdAt,asc' | 'title,asc' | 'title,desc'
  final bool sharedOnly;
  final ValueChanged<String?> onChanged;
  final ValueChanged<bool> onToggleSharedOnly;
  const _AlbumSortDropdown({
    required this.value,
    required this.sharedOnly,
    required this.onChanged,
    required this.onToggleSharedOnly,
  });

  @override
  Widget build(BuildContext context) {
    const sorts = <Map<String, String>>[
      {'value': 'createdAt,desc', 'label': '최신순'},
      {'value': 'createdAt,asc', 'label': '오래된순'},
      {'value': 'title,asc', 'label': '이름순'},
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
          itemBuilder: (ctx) => [
            ...sorts.map(
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
            ),
            const PopupMenuDivider(height: 6),
            PopupMenuItem<String>(
              value: value, // 선택 시 정렬 값 유지
              enabled: false, // PopupMenuItem 자체 클릭 비활성화
              child: InkWell(
                onTap: () => onToggleSharedOnly(!sharedOnly),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: sharedOnly,
                        onChanged: (_) => onToggleSharedOnly(!sharedOnly),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '공유 앨범만 보기',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;
  const _PhotoCard({
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

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
        onLongPress: onLongPress,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.grey[200],
                child: Center(child: imageWidget),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [if (item.favorite) const _FavoriteBadge()],
              ),
            ),
            if (isSelectionMode)
              Positioned(
                top: 8,
                left: 8,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.black45,
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: 18,
                  ),
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
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) => const _ThumbFallback(),
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
      );
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
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
    return Stack(
      alignment: Alignment.center,
      children: [
        // 테두리용 검은색 하트 (약간 크게)
        Icon(Icons.favorite, color: Colors.black.withOpacity(0.5), size: 20),
        // 앞에 배치할 흰색 하트
        const Icon(Icons.favorite, color: Colors.white, size: 18),
      ],
    );
  }
}

class _ShareBadge extends StatelessWidget {
  const _ShareBadge();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 테두리용 검은색 공유 아이콘 (약간 크게)
        Icon(Icons.share, color: Colors.black.withOpacity(0.5), size: 20),
        // 앞에 배치할 흰색 공유 아이콘
        const Icon(Icons.share, color: Colors.white, size: 18),
      ],
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

class _AlbumListGrid extends StatefulWidget {
  final String sort;
  final bool sharedOnly;
  const _AlbumListGrid({
    super.key,
    required this.sort,
    this.sharedOnly = false,
  });

  @override
  State<_AlbumListGrid> createState() => _AlbumListGridState();
}

class _AlbumListGridState extends State<_AlbumListGrid> {
  int? _pressedIndex;
  List<Map<String, dynamic>> _albums = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final int _size = 10;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    // 앨범 탭을 눌렀을 때 항상 최신 앨범 목록 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadAlbums(reset: true);
    });
  }

  // 앨범 목록 새로고침을 위한 public 메서드
  void refresh() {
    _loadAlbums(reset: true);
  }

  Future<void> _loadAlbums({bool reset = false}) async {
    if (!mounted || _isLoading) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _albums = [];
        _page = 0;
        _hasMore = true;
      }
    });

    try {
      final ownership = widget.sharedOnly ? 'SHARED' : 'ALL';
      // ownership이 'ALL'이면 공유 앨범 정보를 먼저 확인 (백엔드가 최신 정보를 반환하도록)
      // 실제로는 백엔드에서 ownership='ALL'로 호출하면 자동으로 공유 앨범도 포함되지만,
      // 공유 앨범 수락 직후에는 약간의 지연이 있을 수 있으므로 잠시 대기
      if (ownership == 'ALL' && reset) {
        // 공유 앨범 수락 직후 반영을 위해 짧은 대기
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        // AlbumProvider의 공유 앨범 정보 새로고침 (소유자가 공유한 앨범 포함)
        try {
          await context.read<AlbumProvider>().refreshSharedAlbums();
        } catch (_) {
          // 무시
        }
      }
      final res = await AlbumApi.getAlbums(
        sort: widget.sort,
        page: _page,
        size: _size,
        ownership: ownership,
      );

      if (!mounted) return;

      final List content = (res['content'] as List? ?? []);
      if (content.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
          _hasLoadedOnce = true; // 초기 로드 완료 표시 (앨범이 없어도 완료로 처리)
        });
      } else {
        final existingIds = _albums.map((e) => e['albumId'] as int).toSet();
        final newAlbums = <Map<String, dynamic>>[];
        for (final m in content) {
          final map = (m as Map).cast<String, dynamic>();
          final albumId = map['albumId'] as int;
          if (!existingIds.contains(albumId)) {
            newAlbums.add(map);
          }
        }

        setState(() {
          _albums.addAll(newAlbums);
          if (content.length < _size) {
            _hasMore = false;
          } else {
            _page += 1;
          }
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void didUpdateWidget(_AlbumListGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // sort 또는 sharedOnly 값이 변경되면 다시 로드
    if (oldWidget.sort != widget.sort ||
        oldWidget.sharedOnly != widget.sharedOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await _loadAlbums(reset: true);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 활성화될 때마다 앨범 목록 새로고침
    // (공유 앨범 수락 후 돌아왔을 때 반영되도록)
    // _albums.isNotEmpty 조건 제거: 앨범이 없어도 새로고침하여 공유 앨범을 가져올 수 있도록
    if (_hasLoadedOnce && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await _loadAlbums(reset: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          if (!_isLoading && _hasMore) {
            _loadAlbums();
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
        itemCount: _albums.length,
        itemBuilder: (_, i) {
          final a = _albums[i];
          final albumId = a['albumId'] as int;
          final title = (a['title'] ?? '') as String;
          final coverPhotoUrl = a['coverPhotoUrl'] as String?;
          final photoCount = (a['photoCount'] as int?) ?? 0;
          final scale = _pressedIndex == i ? 0.96 : 1.0;
          
          // AlbumProvider에서 즐겨찾기 및 공유 상태 가져오기
          final albumProvider = context.read<AlbumProvider>();
          final isFavorited = albumProvider.isFavorited(albumId) || 
                             (a['favorited'] as bool?) == true;
          // 공유 표시: 공유받은 앨범(role != OWNER) 또는 소유자가 공유한 앨범(isShared)
          final role = (a['role'] as String?)?.toUpperCase();
          final isShared = (role != null && role != 'OWNER') || 
                          albumProvider.isShared(albumId);
          
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
                            builder: (_) => AlbumDetailScreen(albumId: albumId),
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
                          await _showAlbumShareSheet(context, albumId);
                        } else if (action == 'download') {
                          try {
                            final count =
                                await PhotoDownloadService.downloadAlbumToGallery(
                                  albumId,
                                );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
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
                              SnackBar(content: Text('다운로드 중 오류: $e')),
                            );
                          }
                        } else if (action == 'fav') {
                          try {
                            await AlbumApi.favoriteAlbum(albumId);
                            if (!mounted) return;
                            setState(() {
                              final idx = _albums.indexWhere(
                                (e) => e['albumId'] == albumId,
                              );
                              if (idx != -1) {
                                _albums[idx] = {
                                  ..._albums[idx],
                                  'favorited': true,
                                };
                              }
                            });
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('즐겨찾기 추가 실패: $e')),
                            );
                          }
                        } else if (action == 'unfav') {
                          try {
                            await AlbumApi.unfavoriteAlbum(albumId);
                            if (!mounted) return;
                            setState(() {
                              final idx = _albums.indexWhere(
                                (e) => e['albumId'] == albumId,
                              );
                              if (idx != -1) {
                                _albums[idx] = {
                                  ..._albums[idx],
                                  'favorited': false,
                                };
                              }
                            });
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('즐겨찾기 해제 실패: $e')),
                            );
                          }
                        } else if (action == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(
                                albumId: albumId,
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
                              await AlbumApi.deleteAlbum(albumId);
                              if (!mounted) return;
                              setState(() {
                                _albums.removeWhere(
                                  (e) => e['albumId'] == albumId,
                                );
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('앨범이 삭제되었습니다.')),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
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
                              child: coverPhotoUrl != null
                                  ? Image.network(
                                      coverPhotoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const ColoredBox(
                                            color: Color(0xFFE0E0E0),
                                          ),
                                    )
                                  : const ColoredBox(color: Color(0xFFE0E0E0)),
                            ),
                            // 즐겨찾기 표시 - AlbumProvider 상태 사용
                            if (isFavorited)
                              const Positioned(
                                right: 6,
                                top: 6,
                                child: Icon(
                                  Icons.favorite,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            // 공유 표시 - AlbumProvider 상태 사용 (소유자가 공유한 앨범도 포함)
                            if (isShared)
                              const Positioned(
                                left: 6,
                                top: 6,
                                child: _ShareBadge(),
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
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${photoCount}장',
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
    String defaultRole = 'VIEWER'; // VIEWER | EDITOR | CO_OWNER
    final Map<int, String> perUserRoles = <int, String>{};
    List<Map<String, dynamic>> friends = await FriendApi.getFriends();
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
                  // 기본 권한 선택
                  Row(
                    children: [
                      const Text(
                        '기본 권한',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      StatefulBuilder(
                        builder: (ctx2, setStateSB) {
                          return DropdownButton<String>(
                            value: defaultRole,
                            items: const [
                              DropdownMenuItem(
                                value: 'VIEWER',
                                child: Text('보기 가능'),
                              ),
                              DropdownMenuItem(
                                value: 'EDITOR',
                                child: Text('수정 가능'),
                              ),
                              DropdownMenuItem(
                                value: 'CO_OWNER',
                                child: Text('공동 소유주'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              defaultRole = v;
                              setStateSB(() {});
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                      return Column(
                        children: List.generate(availableFriends.length, (idx) {
                          final f = availableFriends[idx];
                          final id = f['userId'] as int;
                          final nick = f['nickname'] as String? ?? '친구$id';
                          final avatarUrl =
                              (f['avatarUrl'] ?? f['profileImageUrl']) as String?;
                          final checked = selectedIds.contains(id);
                          final role = perUserRoles[id] ?? defaultRole;
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
                                DropdownButton<String>(
                                  value: role,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'VIEWER',
                                      child: Text('보기 가능'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'EDITOR',
                                      child: Text('수정 가능'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'CO_OWNER',
                                      child: Text('공동 소유주'),
                                    ),
                                  ],
                                  onChanged: checked
                                      ? (v) {
                                          if (v == null) return;
                                          perUserRoles[id] = v;
                                          (ctx as Element).markNeedsBuild();
                                        }
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Checkbox(
                                  value: checked,
                                  onChanged: (v) {
                                    if (v == true) {
                                      selectedIds.add(id);
                                      perUserRoles[id] =
                                          perUserRoles[id] ?? defaultRole;
                                    } else {
                                      selectedIds.remove(id);
                                      perUserRoles.remove(id);
                                    }
                                    (ctx as Element).markNeedsBuild();
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              if (checked) {
                                selectedIds.remove(id);
                                perUserRoles.remove(id);
                              } else {
                                selectedIds.add(id);
                                perUserRoles[id] = perUserRoles[id] ?? defaultRole;
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
          defaultRole: defaultRole,
          perUserRoles: perUserRoles.isEmpty ? null : perUserRoles,
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
}

class _AlbumQuickActions extends StatelessWidget {
  final Map<String, dynamic> album;
  const _AlbumQuickActions({required this.album});

  @override
  Widget build(BuildContext context) {
    final isFav = (album['favorited'] as bool?) == true;
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
                leading: const Icon(Icons.download_rounded),
                title: const Text('다운로드'),
                onTap: () => Navigator.pop(context, 'download'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('수정'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.red : null,
                ),
                title: Text(isFav ? '즐겨찾기 해제' : '즐겨찾기 추가'),
                onTap: () => Navigator.pop(context, isFav ? 'unfav' : 'fav'),
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

/// 글라스모피즘 스타일의 FloatingActionButton (둥근 네모)
class _GlassFloatingActionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GlassFloatingActionButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 16, bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onPressed,
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _FloatingSortButton 제거됨: 상단 우측 드롭다운으로 대체
