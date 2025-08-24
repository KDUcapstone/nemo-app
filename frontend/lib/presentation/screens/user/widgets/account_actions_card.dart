import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'glass_card.dart';
import 'menu_button.dart';

class AccountActionsCard extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onDelete;

  const AccountActionsCard({
    super.key,
    required this.onLogout,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계정 관리',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          MenuButton(
            icon: Icons.logout,
            label: '로그아웃',
            onTap: onLogout,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          MenuButton(
            icon: Icons.delete_forever,
            label: '회원탈퇴',
            onTap: onDelete,
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}
