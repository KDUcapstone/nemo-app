import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';

class YearRecapScreen extends StatelessWidget {
  const YearRecapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('연말 리캡'),
        backgroundColor: AppColors.secondary,
        surfaceTintColor: Colors.transparent,
      ),
      body: const Center(child: Text('연말 리캡 준비 중입니다.')),
    );
  }
}

