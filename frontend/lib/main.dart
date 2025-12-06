// 📁 lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ 폰트 적용을 위해 import
import 'package:flutter_naver_map/flutter_naver_map.dart'; // ✅ 네이버맵 패키지 import
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart'; // 카카오 연동 패키지
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 환경변수 패키지
import 'services/auth_service.dart';
import 'app/theme/app_colors.dart'; // ✅ 색상 테마 적용을 위해 import
import 'presentation/screens/login/login_screen.dart';
import 'presentation/screens/main_shell.dart';
import 'providers/user_provider.dart';
import 'providers/provider.dart';
import 'package:provider/provider.dart';
import 'widgets/auth_guard.dart';

void main() async {
  // 플러그인 초기화를 보장 (camera 등)
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ .env 파일 로드
  await dotenv.load(fileName: ".env");

  // 👉 네이티브 앱 키로 Kakao SDK 초기화
  KakaoSdk.init(nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY']!,);

  // 👉 이 줄 추가해서 실제 키해시를 로그로 출력
  final keyHash = await KakaoSdk.origin;
  print('🔑 Kakao keyHash: $keyHash');

  // ✅ 서버 baseUrl 자동 결정 (원격 서버 health 체크 → 실패 시 로컬로 fallback)
  await AuthService.initBaseUrl();

  // ✅ 네이버맵 초기화 (NaverMap 위젯 사용 전 필수!)
  await FlutterNaverMap().init(
    clientId: 'iclhyt3mb3', // 네이버 클라우드 플랫폼에서 발급받은 Client ID
    onAuthFailed: (ex) {
      print('네이버맵 인증 실패: $ex');
    },
  );

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
        home: const _RootGate(),
      ),
    );
  }
}

/// 앱 시작 시 자동 로그인 여부를 판단해 초기 화면을 결정하는 게이트
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _initialized = false;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final result = await AuthService.tryAutoLogin();
    if (!mounted) return;

    if (result.success && result.userId != null && result.accessToken != null) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUser(
        userId: result.userId!,
        nickname: result.nickname ?? '',
        accessToken: result.accessToken!,
        profileImageUrl: result.profileImageUrl,
        context: context,
      );
      setState(() {
        _initialized = true;
        _loggedIn = true;
      });
    } else {
      setState(() {
        _initialized = true;
        _loggedIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return _loggedIn
        ? const AuthGuard(child: MainShell())
        : const LoginScreen();
  }
}

