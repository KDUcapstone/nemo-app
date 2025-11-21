import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('타임라인'),
        backgroundColor: AppColors.secondary,
        surfaceTintColor: Colors.transparent,
      ),
      body: const Center(child: Text('타임라인 준비 중입니다.')),
    );
  }
}

