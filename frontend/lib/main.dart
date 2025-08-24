// 📁 lib/main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ 폰트 적용을 위해 import
import 'app/theme/app_colors.dart'; // ✅ 색상 테마 적용을 위해 import
import 'presentation/screens/login/login_screen.dart';
import 'providers/provider.dart';

void main() async {
  // 플러그인 초기화를 보장 (camera 등)
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NemoApp());
}

class NemoApp extends StatelessWidget {
  const NemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ 기존의 훌륭한 AppProviders 구조는 그대로 유지합니다.
    return AppProviders(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '네컷모아(nemo)', // 앱의 공식 명칭을 title에 추가
        // ✅ 제가 제안드린 Theme 데이터를 여기에 적용합니다.
        theme: ThemeData(
          useMaterial3: true, // 모던한 Material 3 디자인 활성화
          scaffoldBackgroundColor: AppColors.background, // 기본 배경색
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          // Noto Sans KR 폰트를 앱의 기본 폰트로 설정
          textTheme: GoogleFonts.notoSansKrTextTheme(
            Theme.of(context).textTheme,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.secondary,
            elevation: 0,
            foregroundColor: AppColors.textPrimary,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        home: const LoginScreen(),
      ),
    );
  }
}
