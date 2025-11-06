import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/providers/photo_provider.dart';
import 'package:frontend/providers/album_provider.dart';
import 'package:frontend/presentation/screens/photo/favorites_screen.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:frontend/presentation/screens/album/album_detail_screen.dart';
import 'package:frontend/app/constants.dart';

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
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('지도 기능 준비 중입니다.')),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  AppConstants.enableHomeMap
                      ? const _HomeNaverMapCard()
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
  const _HomeNaverMapCard();

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: NaverMap(
          options: const NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: NLatLng(37.5665, 126.9780), // 서울 시청
              zoom: 14,
            ),
            locationButtonEnable: true,
          ),
          onMapReady: (controller) async {
            // 이후: onCameraIdle 에서 MapApi.getViewport 호출 및 마커 추가
          },
        ),
      ),
    );
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

class _MemoryShelfRow extends StatelessWidget {
  const _MemoryShelfRow();

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
    if (albumProvider.albums.isEmpty && !albumProvider.isLoading) {
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
