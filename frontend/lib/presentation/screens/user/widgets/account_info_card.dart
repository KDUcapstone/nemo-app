import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'glass_card.dart';
import 'info_row.dart';

class AccountInfoCard extends StatelessWidget {
  final String createdAt;
  final String email;

  const AccountInfoCard({
    super.key,
    required this.createdAt,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '계정 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 16),
          // InfoRow들은 부모에서 주입할 수도 있으나 단순화를 위해 여기서 표기
        ],
      ),
    );
  }
}
