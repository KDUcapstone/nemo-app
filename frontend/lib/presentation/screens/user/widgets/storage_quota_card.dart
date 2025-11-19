import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/services/storage_api.dart';

class StorageQuotaCard extends StatelessWidget {
  final StorageQuota quota;
  final VoidCallback onUpgrade;
  final bool capFreeAtTwenty;

  const StorageQuotaCard({
    super.key,
    required this.quota,
    required this.onUpgrade,
    this.capFreeAtTwenty = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFree = quota.planType.toUpperCase() == 'FREE';

    // FREE 플랜은 표시 기준을 20장으로 고정
    final int displayMax = (capFreeAtTwenty && isFree) ? 20 : quota.maxPhotos;
    final int used = quota.usedPhotos.clamp(0, 1 << 31);

    final double progress = displayMax > 0
        ? (used / displayMax).clamp(0.0, 1.0)
        : 0.0;

    final NumberFormat nf = NumberFormat.decimalPattern();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 타이틀 제거 요청 반영
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '요금제: ${quota.planType}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                color: _progressColor(context, progress),
              ),
            ),
            const SizedBox(height: 8),
            // 중앙 정렬: 진행률(%)와 n/20장 표기
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    // n/20 형식 요구사항 반영
                    '${nf.format(used)} / ${nf.format(displayMax)}장',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: FilledButton(
                onPressed: onUpgrade,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(90, 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text('업그레이드', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _progressColor(BuildContext context, double v) {
    if (v >= 0.9) return Colors.redAccent;
    if (v >= 0.75) return Colors.orange;
    return Theme.of(context).colorScheme.primary;
  }
}
