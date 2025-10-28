import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/app/theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 12),
            _SectionHeader(
              title: '내 주변 포토부스 찾기',
              onTap: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('지도 기능 준비 중입니다.')));
              },
            ),
            const SizedBox(height: 8),
            const _MapPreviewCard(),
            const SizedBox(height: 20),
            _SectionHeader(
              title: '추억 저장소',
              onTap: () {
                // 향후: 앨범 탭으로 이동하거나 추천/전체 보기로 이동
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('추억 저장소로 이동합니다.')));
              },
            ),
            const SizedBox(height: 8),
            const _MemoryShelfRow(),
          ],
        ),
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

class _MapPreviewCard extends StatelessWidget {
  const _MapPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.skyLight, AppColors.skyMid],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.map_outlined, size: 48, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text(
                    '지도 미리보기 (준비 중)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
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

class _MemoryShelfRow extends StatelessWidget {
  const _MemoryShelfRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _MemoryCard(variant: _MemoryCardVariant.blue)),
        SizedBox(width: 12),
        Expanded(child: _MemoryCard(variant: _MemoryCardVariant.red)),
      ],
    );
  }
}

enum _MemoryCardVariant { blue, red }

class _MemoryCard extends StatelessWidget {
  final _MemoryCardVariant variant;
  const _MemoryCard({required this.variant});

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
    return Container(
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
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(isBlue ? 0.9 : 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isBlue ? '최근 앨범' : '즐겨찾기',
                style: TextStyle(
                  color: isBlue ? AppColors.textPrimary : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              isBlue ? Icons.photo_library_rounded : Icons.favorite_rounded,
              size: 72,
              color: isBlue ? AppColors.primary : Colors.white,
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
        ],
      ),
    );
  }
}
