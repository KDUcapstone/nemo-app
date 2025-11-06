import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.group_outlined, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('공유 기능 준비 중입니다.',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}


