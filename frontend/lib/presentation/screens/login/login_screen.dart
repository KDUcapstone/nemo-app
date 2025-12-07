// 📁 lib/presentation/screens/login/login_screen.dart
// removed unnecessary imports
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/providers/user_provider.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../main_shell.dart';
import 'widgets/login_background.dart';
import 'widgets/login_logo.dart';
import 'widgets/email_login_form.dart';
import 'widgets/social_login_buttons.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

GoogleSignIn _buildGoogleSignIn() {
  // serverClientId 필요 없음 (idToken만 사용할 거라서)
  return GoogleSignIn(
    scopes: ['email', 'profile'],
  );
}


class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const LoginBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      child: const LoginLogo(),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 16),
                            child: Transform.scale(
                              scale: 0.95 + 0.05 * value,
                              child: child,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '네컷 모아',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jua(
                        fontSize: 32,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _AnimatedPrimaryButton(
                      text: '이메일로 시작하기',
                      gradientColors: const [
                        AppColors.skyMid,
                        AppColors.primary,
                      ],
                      onTap: () => _showEmailLoginSheet(context),
                    ),
                    const SizedBox(height: 28),
                    SocialLoginButtons(
                      onKakaoTap: () => _handleKakaoLogin(context),
                      onGoogleTap: () => _handleGoogleLogin(context),
                    ),
                    // TODO: 소셜 로그인 연동 후, 이메일/소셜 로그인 성공 시에만 메인으로 진입
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showEmailLoginSheet(BuildContext context) async {
  final result = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    barrierColor: Colors.black26,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return const EmailLoginForm();
          },
        ),
      );
    },
  );
  if (result == true) {
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }
}

Future<void> _handleKakaoLogin(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  print('🟡 [UI] 카카오 로그인 버튼 탭');

  try {
    // 1) 카카오 SDK로 액세스 토큰 받기
    kakao.OAuthToken token;

    final installed = await kakao.isKakaoTalkInstalled();
    print('🟡 [UI] isKakaoTalkInstalled=$installed');

    if (installed) {
      print('🟡 [UI] KakaoTalk 설치됨 → loginWithKakaoTalk 호출');
      token = await kakao.UserApi.instance.loginWithKakaoTalk();
    } else {
      print('🟡 [UI] KakaoTalk 미설치 → loginWithKakaoAccount 호출');
      token = await kakao.UserApi.instance.loginWithKakaoAccount();
    }

    // 토큰 내용 일부만 로그 (전체 찍으면 너무 김)
    final access = token.accessToken;
    print('🟢 [UI] Kakao OAuthToken 수신: '
        'len=${access.length}, prefix=${access.substring(0, 12)}...');

    // 2) 백엔드로 토큰 전달 → 우리 서버 로그인/회원가입
    final authService = AuthService();
    print('🟡 [UI] AuthService.loginWithKakao 호출 시작');
    final result = await authService.loginWithKakao(access);
    print('🟢 [UI] AuthService.loginWithKakao 응답: $result');

    // 3) 카카오에서 실제 사용자 프로필 조회
    print('🟡 [UI] Kakao UserApi.instance.me() 호출');
    final kakaoUser = await kakao.UserApi.instance.me();
    final kakaoAccount = kakaoUser.kakaoAccount;
    final kakaoProfile = kakaoAccount?.profile;

    final nicknameFromKakao = kakaoProfile?.nickname;
    final profileImageFromKakao = kakaoProfile?.profileImageUrl;

    print('🟢 [UI] Kakao 프로필: '
        'nickname=$nicknameFromKakao, profileImage=$profileImageFromKakao');

    // 4) UserProvider에 상태 반영
    if (result['userId'] != null && result['accessToken'] != null) {
      final userProvider = Provider.of<UserProvider>(
        context,
        listen: false,
      );

      print('💾 [UI] UserProvider.setUser 호출');
      userProvider.setUser(
        userId: result['userId'] as int,
        // 서버 닉네임보다 카카오 닉네임을 우선 사용
        nickname: nicknameFromKakao ?? (result['nickname'] as String? ?? ''),
        accessToken: result['accessToken'] as String,
        // 서버 프로필보다 카카오 프로필을 우선 사용
        profileImageUrl:
        profileImageFromKakao ?? (result['profileImageUrl'] as String?),
        provider: result['provider'],      // 👈 provider도 찍힘
        context: context,
      );
      print('💾 [UI] UserProvider.setUser 완료');

      // 5) 메인 화면으로 이동
      print('🟡 [UI] MainShell로 네비게이션');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('카카오로 로그인되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      print('🔴 [UI] 로그인 결과에 userId 또는 accessToken 없음: $result');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('카카오 로그인에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e, st) {
    print('🔴 [UI] _handleKakaoLogin 예외: $e');
    print(st);
    messenger.showSnackBar(
      SnackBar(
        content: Text('카카오 로그인 오류: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _handleGoogleLogin(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  print('🟡 [UI] Google 로그인 버튼 탭');

  try {
    // 1) Google 계정 선택
    print('🟡 [UI] _googleSignIn.signIn() 호출');
    final googleSignIn = _buildGoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      print('🟡 [UI] 사용자가 Google 로그인 취소함 (googleUser == null)');
      return; // 사용자가 취소한 경우
    }

    print('🟢 [UI] Google 계정 선택 완료: '
        'id=${googleUser.id}, email=${googleUser.email}, displayName=${googleUser.displayName}');

    // 2) Google 인증 정보에서 idToken 가져오기
    print('🟡 [UI] googleUser.authentication 호출');
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      print('🔴 [UI] googleAuth.idToken == null');
      throw Exception('Google idToken 이 비어 있습니다.');
    }

    print('🟢 [UI] Google idToken 획득: '
        'len=${idToken.length}, prefix=${idToken.substring(0, 12)}...');

    // 3) 우리 백엔드로 Google idToken 보내서 로그인/회원가입
    final authService = AuthService();
    print('🟡 [UI] AuthService.loginWithGoogle 호출 시작');
    final result = await authService.loginWithGoogle(idToken);
    print('🟢 [UI] AuthService.loginWithGoogle 응답: $result');

    // 4) UserProvider에 상태 반영
    if (result['userId'] != null && result['accessToken'] != null) {
      final userProvider = Provider.of<UserProvider>(
        context,
        listen: false,
      );

      print('💾 [UI] UserProvider.setUser 호출 (Google)');
      userProvider.setUser(
        userId: result['userId'] as int,
        nickname: result['nickname'] as String? ?? '',
        accessToken: result['accessToken'] as String,
        profileImageUrl: result['profileImageUrl'] as String?,
        provider: result['provider'],      // 👈 여기서 provider도 넘겨줌
        context: context,
      );
      print('💾 [UI] UserProvider.setUser 완료 (Google)');

      // 5) 메인 화면으로 이동
      print('🟡 [UI] MainShell로 네비게이션 (Google)');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Google로 로그인되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      print('🔴 [UI] Google 로그인 결과에 userId 또는 accessToken 없음: $result');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Google 로그인에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e, st) {
    print('🔴 [UI] _handleGoogleLogin 예외: $e');
    print(st);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Google 로그인 오류: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class _EmailLoginForm extends StatefulWidget {
  @override
  State<_EmailLoginForm> createState() => _EmailLoginFormState();
}

class _EmailLoginFormState extends State<_EmailLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '이메일을 입력해주세요';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return '올바른 이메일 형식을 입력해주세요';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요';
    }
    if (value.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다';
    }
    return null;
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        final authService = AuthService();
        final result = await authService.login(
          _emailController.text,
          _passwordController.text,
        );

        // API 명세서: 로그인 성공 시 { accessToken, refreshToken, expiresIn, user: { userId, nickname, profileImageUrl } }
        // AuthService.login()은 성공 시 userId, nickname, accessToken, profileImageUrl을 최상위에도 제공
        if (result['userId'] != null && result['accessToken'] != null) {
          if (!mounted) return;
          // UserProvider에 사용자 정보 저장
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          userProvider.setUser(
            userId: result['userId'] as int,
            nickname: result['nickname'] as String? ?? '',
            accessToken: result['accessToken'] as String,
            profileImageUrl: result['profileImageUrl'] as String?,
            context: context,
          );

          // 로그인 성공 시 화면 이동
          if (mounted) {
            Navigator.pop(context); // 로그인 바텀시트 닫기
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('로그인되었습니다!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // 예상치 못한 응답 형식
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('로그인에 실패했습니다.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          final errorMsg = e.toString();
          String message;

          // Exception 접두사 제거, 사용자 친화적인 메시지로 변환
          if (errorMsg.startsWith('Exception: ')) {
            message = errorMsg.substring('Exception: '.length);
            
            // 실제 네트워크 오류만 "네트워크 오류"로 변환
            if (message.startsWith('네트워크 오류: ') ||
                message.contains('서버에 연결할 수 없습니다') ||
                message.contains('SSL 인증서 오류') ||
                message.contains('요청 시간이 초과')) {
              message = message.startsWith('네트워크 오류: ')
                  ? '네트워크 오류가 발생했습니다.'
                  : message; // 구체적인 네트워크 오류 메시지는 그대로 표시
            }
            // 기술적인 오류 코드만 포함된 경우 (백엔드 메시지가 없는 경우)에만 일반 메시지로 변환
            else if ((message.contains('(40') ||
                    message.contains('(50') ||
                    message.contains('statusCode') ||
                    message.contains('HttpException')) &&
                !message.contains('이메일') &&
                !message.contains('비밀번호') &&
                !message.contains('올바르지') &&
                !message.contains('틀렸')) {
              message = '로그인에 실패했습니다.';
            }
            // 그 외의 경우는 백엔드에서 보낸 메시지를 그대로 표시
          } else if (errorMsg.contains('네트워크') ||
              errorMsg.contains('Network')) {
            message = '네트워크 오류가 발생했습니다.';
          } else {
            // 백엔드에서 보낸 구체적인 메시지가 있으면 그대로 표시
            message = errorMsg.startsWith('Exception: ')
                ? errorMsg.substring('Exception: '.length)
                : '로그인에 실패했습니다.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: ListView(
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '이메일로 로그인',
            style: GoogleFonts.jua(fontSize: 22, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _IconInputField(
                  hintText: '이메일 입력',
                  keyboardType: TextInputType.emailAddress,
                  icon: Icons.email_outlined,
                  strongBorder: true,
                  controller: _emailController,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                _IconInputField(
                  hintText: '비밀번호 입력',
                  obscureText: true,
                  icon: Icons.lock_outline,
                  strongBorder: true,
                  controller: _passwordController,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                _PrimaryButton(text: '로그인', onTap: _handleLogin),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text('비밀번호 재설정'),
                    ),
                    const SizedBox(width: 8),
                    const Text('|'),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                      child: const Text('회원가입하기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconInputField extends StatefulWidget {
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData icon;
  final bool strongBorder;
  final String? Function(String?)? validator;
  final TextEditingController? controller;

  const _IconInputField({
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.strongBorder = false,
    this.validator,
    this.controller,
  });

  @override
  State<_IconInputField> createState() => _IconInputFieldState();
}

class _IconInputFieldState extends State<_IconInputField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFocused = _focusNode.hasFocus;
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(widget.icon, size: 20, color: AppColors.textSecondary),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 36,
        ),
        hintText: isFocused ? '' : widget.hintText,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.9),
        ),
        filled: true,
        fillColor: widget.strongBorder
            ? Colors.white
            : Colors.white.withValues(alpha: 0.28),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: widget.strongBorder
                ? AppColors.divider
                : Colors.white.withValues(alpha: 0.5),
            width: widget.strongBorder ? 1 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: widget.strongBorder ? 1.4 : 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.4),
        ),
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final List<Color>? gradientColors;

  const _PrimaryButton({
    required this.text,
    required this.onTap,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                gradientColors ??
                [
                  AppColors.primary.withValues(alpha: 0.95),
                  AppColors.primary.withValues(alpha: 0.75),
                ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _AnimatedPrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final List<Color>? gradientColors;

  const _AnimatedPrimaryButton({
    required this.text,
    required this.onTap,
    this.gradientColors,
  });

  @override
  State<_AnimatedPrimaryButton> createState() => _AnimatedPrimaryButtonState();
}

class _AnimatedPrimaryButtonState extends State<_AnimatedPrimaryButton> {
  bool _pressed = false;
  void _set(bool v) => setState(() => _pressed = v);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.98 : 1,
        child: _PrimaryButton(
          text: widget.text,
          onTap: widget.onTap,
          gradientColors: widget.gradientColors,
        ),
      ),
    );
  }
}

// removed local _AnimatedSocialButton (moved to widgets/social_login_buttons.dart)

class _PressScale extends StatefulWidget {
  final Widget child;

  const _PressScale({required this.child});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;
  void _set(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.98 : 1,
        child: Stack(alignment: Alignment.center, children: [widget.child]),
      ),
    );
  }
}

// Removed local background and logo; using widgets/login_background.dart and widgets/login_logo.dart
