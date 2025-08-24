import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';

class ResetInfoCard extends StatelessWidget {
  const ResetInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '가입하신 이메일 주소를 입력하시면\n비밀번호 재설정 링크를 발송해드립니다.',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
