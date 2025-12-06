import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/presentation/screens/login/login_screen.dart';

/// 액세스/리프레시 토큰이 없으면 어떤 화면이든 로그인 화면으로 강제 이동시키는 가드
class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, user, _) {
        final hasAccess = user.isLoggedIn &&
            AuthService.accessToken != null &&
            AuthService.refreshToken != null;

        if (!hasAccess) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          });
          return const SizedBox.shrink();
        }

        return child;
      },
    );
  }
}


