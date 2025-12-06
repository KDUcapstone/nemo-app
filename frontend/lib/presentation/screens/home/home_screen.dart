import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/providers/photo_provider.dart';
import 'package:frontend/providers/album_provider.dart';
import 'package:frontend/presentation/screens/photo/favorites_screen.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:frontend/presentation/screens/album/album_detail_screen.dart';
import 'package:frontend/app/constants.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/services/map_api.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/presentation/screens/notification/notification_bottom_sheet.dart';
import 'package:frontend/widgets/notification_badge_icon.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _buildTopBar(context),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: '내 주변 포토부스 찾기',
                    onTap: () => _openFullMap(context),
                  ),
                  const SizedBox(height: 8),
                  AppConstants.enableHomeMap
                      ? _HomeNaverMapCard(onTap: () => _openFullMap(context))
                      : const _HomeMapPlaceholderCard(),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: '추억 저장소',
                    onTap: () {
                      // 향후: 앨범 탭으로 이동하거나 추천/전체 보기로 이동
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('추억 저장소로 이동합니다.')),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const _MemoryShelfRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
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

  void _openFullMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapFullScreen()),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SectionHeader({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          '$title >',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _HomeNaverMapCard extends StatelessWidget {
  final VoidCallback onTap;

  const _HomeNaverMapCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _MapContent(isFullScreen: false, onTapExpand: onTap),
        ),
      ),
    );
  }
}

class _MapContent extends StatefulWidget {
  final bool isFullScreen;
  final VoidCallback? onTapExpand;

  const _MapContent({required this.isFullScreen, this.onTapExpand});

  @override
  State<_MapContent> createState() => _MapContentState();
}

class _MapContentState extends State<_MapContent> {
  NaverMapController? _mapController;
  final Set<NMarker> _markers = {};
  Timer? _debounceTimer;
  NLatLng? _lastLoadedCenter;
  bool _isLoading = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NaverMap(
          options: const NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: NLatLng(37.5665, 126.9780),
              zoom: 14,
            ),
            locationButtonEnable: true,
          ),
          onMapReady: _onMapReady,
          onCameraIdle: _onCameraIdle,
        ),
        if (!widget.isFullScreen && widget.onTapExpand != null)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: widget.onTapExpand),
            ),
          ),
        if (_isLoading)
          Positioned(
            top: widget.isFullScreen ? 16 : 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('포토부스 검색 중...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );

        final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(position.latitude, position.longitude),
          zoom: 15,
        );
        await controller.updateCamera(cameraUpdate);
      } else {
        await _loadPhotobooths();
      }
    } catch (e) {
      debugPrint('위치 가져오기 실패: $e');
      await _loadPhotobooths();
    }
  }

  Future<void> _onCameraIdle() async {
    if (_mapController == null) return;

    final cameraPosition = await _mapController!.getCameraPosition();

    if (_lastLoadedCenter != null) {
      final distance = Geolocator.distanceBetween(
        _lastLoadedCenter!.latitude,
        _lastLoadedCenter!.longitude,
        cameraPosition.target.latitude,
        cameraPosition.target.longitude,
      );

      if (distance < 150) return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _lastLoadedCenter = cameraPosition.target;
      _loadPhotobooths();
    });
  }

  Future<void> _loadPhotobooths() async {
    if (_mapController == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final bounds = await _mapController!.getContentBounds();
      final cameraPosition = await _mapController!.getCameraPosition();

      final response = await MapApi.getViewport(
        neLat: bounds.northEast.latitude,
        neLng: bounds.northEast.longitude,
        swLat: bounds.southWest.latitude,
        swLng: bounds.southWest.longitude,
        zoom: cameraPosition.zoom.toInt(),
        cluster: true,
        limit: 300,
      );

      debugPrint('📍 [Map] API 응답: ${response['items']?.length ?? 0}개 아이템');

      if (!mounted) return;

      _mapController!.clearOverlays(type: NOverlayType.marker);
      _markers.clear();

      final items = response['items'] as List<dynamic>? ?? [];
      debugPrint('📍 [Map] 마커 추가 시작: ${items.length}개');

      for (final item in items) {
        try {
          await _addMarker(item);
        } catch (e) {
          debugPrint('❌ [Map] 마커 추가 실패: ${item['placeId']}, 에러: $e');
        }
      }

      debugPrint('📍 [Map] 최종 마커 개수: ${_markers.length}개');
    } catch (e) {
      debugPrint('❌ [Map] 포토부스 로딩 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('포토부스 정보를 불러올 수 없습니다: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addMarker(Map<String, dynamic> item) async {
    if (_mapController == null) return;

    final placeId = item['placeId'] as String;
    final latitude = item['latitude'] as double;
    final longitude = item['longitude'] as double;
    final brand = item['brand'] as String?;
    final isCluster = item['cluster'] == true;

    final marker = NMarker(id: placeId, position: NLatLng(latitude, longitude));

    if (isCluster) {
      final count = item['count'] as int? ?? 0;
      marker.setIcon(
        await NOverlayImage.fromWidget(
          context: context,
          widget: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          size: const Size(32, 32),
        ),
      );
    } else {
      String iconPath = _getMarkerIconPath(brand);
      try {
        final ByteData data = await rootBundle.load(iconPath);
        final Uint8List imageBytes = data.buffer.asUint8List();

        final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final ui.Image image = frameInfo.image;

        marker.setIcon(
          await NOverlayImage.fromWidget(
            context: context,
            widget: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: RawImage(
                  image: image,
                  fit: BoxFit.cover,
                  width: 30,
                  height: 30,
                ),
              ),
            ),
            size: const Size(36, 36),
          ),
        );
      } catch (e) {
        // 기본 마커 아이콘: 앱 로고 사용
        try {
          final ByteData logoData = await rootBundle.load('assets/app_icon.png');
          final Uint8List logoBytes = logoData.buffer.asUint8List();

          final ui.Codec logoCodec = await ui.instantiateImageCodec(logoBytes);
          final ui.FrameInfo logoFrameInfo = await logoCodec.getNextFrame();
          final ui.Image logoImage = logoFrameInfo.image;

          marker.setIcon(
            await NOverlayImage.fromWidget(
              context: context,
              widget: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: RawImage(
                    image: logoImage,
                    fit: BoxFit.cover,
                    width: 30,
                    height: 30,
                  ),
                ),
              ),
              size: const Size(36, 36),
            ),
          );
        } catch (logoError) {
          // 앱 로고 로드 실패 시 카메라 아이콘 사용 (폴백)
          marker.setIcon(
            await NOverlayImage.fromWidget(
              context: context,
              widget: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: _getBrandColor(brand),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              size: const Size(36, 36),
            ),
          );
        }
      }

      marker.setOnTapListener((overlay) {
        _onMarkerTapped(item);
      });
    }

    _mapController!.addOverlay(marker);
    _markers.add(marker);
  }

  String _getMarkerIconPath(String? brand) {
    if (brand == null) return 'assets/markers/default.png';

    final brandLower = brand.toLowerCase();
    if (brandLower.contains('인생네컷')) {
      return 'assets/markers/lifefourcuts.png';
    } else if (brandLower.contains('포토그레이')) {
      return 'assets/markers/photogray.png';
    } else if (brandLower.contains('하루필름')) {
      return 'assets/markers/harufilm.png';
    } else if (brandLower.contains('포토이즘')) {
      return 'assets/markers/photoism.png';
    }
    return 'assets/markers/default.png';
  }

  Color _getBrandColor(String? brand) {
    if (brand == null) return AppColors.primary;

    final brandLower = brand.toLowerCase();
    if (brandLower.contains('인생네컷')) {
      return const Color(0xFFFF6B6B);
    } else if (brandLower.contains('포토그레이')) {
      return const Color(0xFF757575);
    } else if (brandLower.contains('하루필름')) {
      return const Color(0xFF64B5F6);
    } else if (brandLower.contains('포토이즘')) {
      return const Color(0xFF9575CD);
    }
    return AppColors.primary;
  }

  void _onMarkerTapped(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '포토부스';
    final address = item['roadAddress'] as String?;
    final brand = item['brand'] as String?;
    final naverPlaceUrl = item['naverPlaceUrl'] as String?;
    final latitude = (item['latitude'] as num?)?.toDouble();
    final longitude = (item['longitude'] as num?)?.toDouble();

    final canLaunchNavigation =
        (latitude != null && longitude != null) ||
        (naverPlaceUrl != null && naverPlaceUrl.isNotEmpty);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (brand != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getBrandColor(brand).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        brand,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getBrandColor(brand),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (address != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
              if (canLaunchNavigation) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _openNaverMap(
                        name: name,
                        latitude: latitude,
                        longitude: longitude,
                        naverPlaceUrl: naverPlaceUrl,
                      );
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('길찾기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNaverMap({
    required String name,
    double? latitude,
    double? longitude,
    String? naverPlaceUrl,
  }) async {
    final encodedName = Uri.encodeComponent(name);
    const appPackageName = 'com.example.frontend';

    Uri? appUri;
    if (latitude != null && longitude != null) {
      appUri = Uri.parse(
        'nmap://place?lat=$latitude&lng=$longitude&name=$encodedName&appname=$appPackageName',
      );
    } else {
      appUri = Uri.parse(
        'nmap://search?query=$encodedName&appname=$appPackageName',
      );
    }

    final Uri webUri = (naverPlaceUrl != null && naverPlaceUrl.isNotEmpty)
        ? Uri.parse(naverPlaceUrl)
        : Uri.parse('https://map.naver.com/v5/search/$encodedName');

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네이버 지도를 열 수 없습니다. 잠시 후 다시 시도해주세요.')),
      );
    }
  }
}

class _HomeMapPlaceholderCard extends StatelessWidget {
  const _HomeMapPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '지도 준비 중입니다.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _MemoryShelfRow extends StatefulWidget {
  const _MemoryShelfRow();

  @override
  State<_MemoryShelfRow> createState() => _MemoryShelfRowState();
}

class _MemoryShelfRowState extends State<_MemoryShelfRow> {
  bool _hasTriedLoad = false;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<PhotoProvider>().items;
    String? latestFavoriteUrl;
    for (final it in items) {
      if (it.favorite) {
        latestFavoriteUrl = it.imageUrl;
        break;
      }
    }

    final albumProvider = context.watch<AlbumProvider>();
    if (albumProvider.albums.isEmpty &&
        !albumProvider.isLoading &&
        !_hasTriedLoad) {
      _hasTriedLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.read<AlbumProvider>().resetAndLoad(sort: 'createdAt,desc');
        }
      });
    }
    final latestAlbum = albumProvider.albums.isNotEmpty
        ? albumProvider.albums.first
        : null;

    return Row(
      children: [
        Expanded(
          child: _MemoryCard(
            variant: _MemoryCardVariant.blue,
            imageUrl: latestAlbum?.coverPhotoUrl,
            subtitle: latestAlbum?.title,
            onTap: latestAlbum == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AlbumDetailScreen(albumId: latestAlbum.albumId),
                      ),
                    );
                  },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MemoryCard(
            variant: _MemoryCardVariant.red,
            imageUrl: latestFavoriteUrl,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _MemoryCardVariant { blue, red }

class _MemoryCard extends StatelessWidget {
  final _MemoryCardVariant variant;
  final String? imageUrl; // 썸네일용
  final String? subtitle; // 최근 앨범 제목 등
  final VoidCallback? onTap;
  const _MemoryCard({
    required this.variant,
    this.imageUrl,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBlue = variant == _MemoryCardVariant.blue;
    final Gradient bg = LinearGradient(
      colors: isBlue
          ? [const Color(0xFFE6F0FF), const Color(0xFFD6E4FF)]
          : [const Color(0xFF2B0000), const Color(0xFF550000)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final card = Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 72,
                      color: Colors.white,
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                ),
              ),
            )
          else
            Center(
              child: Icon(
                isBlue ? Icons.photo_library_rounded : Icons.favorite_rounded,
                size: 72,
                color: isBlue ? AppColors.primary : Colors.white,
              ),
            ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isBlue ? '최근 앨범' : '즐겨찾기',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Icon(
              Icons.chevron_right_rounded,
              color: isBlue ? AppColors.textSecondary : Colors.white,
            ),
          ),
          if (isBlue && subtitle != null && subtitle!.trim().isNotEmpty)
            Positioned(
              left: 12,
              bottom: 12,
              right: 44, // 우측 화살표와 간격 확보
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class MapFullScreen extends StatelessWidget {
  const MapFullScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 주변 포토부스'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const _MapContent(isFullScreen: true),
    );
  }
}
