// 📁 lib/main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ 폰트 적용을 위해 import
import 'package:flutter_naver_map/flutter_naver_map.dart'; // ✅ 네이버맵 패키지 import
import 'app/theme/app_colors.dart'; // ✅ 색상 테마 적용을 위해 import
import 'presentation/screens/login/login_screen.dart';
import 'providers/provider.dart';

void main() async {
  // 플러그인 초기화를 보장 (camera 등)
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 네이버맵 초기화 (NaverMap 위젯 사용 전 필수!)
  // 모바일 플랫폼(Android/iOS)에서만 초기화 (Windows/Web 등에서는 지원 안 됨)
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await FlutterNaverMap().init(
        clientId: 'iclhyt3mb3', // 네이버 클라우드 플랫폼에서 발급받은 Client ID
        onAuthFailed: (ex) {
          print('네이버맵 인증 실패: $ex');
        },
      );
    } catch (e) {
      // Windows/Web 등 지원되지 않는 플랫폼에서 실행 시 에러 무시
      print('네이버맵 초기화 실패 (지원되지 않는 플랫폼일 수 있음): $e');
    }
  }

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
        // 한글 로케일 설정
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [
          Locale('ko', 'KR'), // 한국어
          Locale('en', 'US'), // 영어
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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
            surfaceTintColor: Colors.transparent,
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
