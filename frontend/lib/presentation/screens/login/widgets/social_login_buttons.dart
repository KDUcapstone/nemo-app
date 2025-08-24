import 'package:flutter/material.dart';

class SocialLoginButtons extends StatelessWidget {
  final VoidCallback onKakaoTap;
  final VoidCallback onGoogleTap;

  const SocialLoginButtons({
    super.key,
    required this.onKakaoTap,
    required this.onGoogleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SocialButton(
          label: '카카오로 시작하기',
          backgroundColor: const Color(0xFFFFE812),
          foregroundColor: Colors.black,
          iconAsset: 'lib/presentation/screens/login/assets/kakao_icon.png',
          onTap: onKakaoTap,
        ),
        const SizedBox(height: 24),
        _SocialButton(
          label: 'Google로 시작하기',
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          iconAsset: 'lib/presentation/screens/login/assets/google_icon.png',
          onTap: onGoogleTap,
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String iconAsset;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.iconAsset,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Image.asset(iconAsset, width: 20, height: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
