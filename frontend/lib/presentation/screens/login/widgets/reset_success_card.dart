import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';

class ResetSuccessCard extends StatelessWidget {
  const ResetSuccessCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          Text(
            '재설정 링크 발송 완료!',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '입력하신 이메일로 비밀번호 재설정 링크가\n발송되었습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '이메일의 링크를 클릭하여\n새로운 비밀번호를 설정해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
