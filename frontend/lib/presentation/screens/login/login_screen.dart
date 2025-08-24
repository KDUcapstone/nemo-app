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
                    const SizedBox(height: 20),
                    Text(
                      '네컷 모아',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jua(
                        fontSize: 32,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _AnimatedPrimaryButton(
                      text: '이메일로 시작하기',
                      gradientColors: const [
                        AppColors.skyMid,
                        AppColors.primary,
                      ],
                      onTap: () => _showEmailLoginSheet(context),
                    ),
                    const SizedBox(height: 24),
                    SocialLoginButtons(
                      onKakaoTap: () {
                        // TODO: 카카오 로그인/회원가입 통합 플로우
                      },
                      onGoogleTap: () {
                        // TODO: 구글 로그인/회원가입 통합 플로우
                      },
                    ),
                    const SizedBox(height: 24),
                    // 임시: 앱 메인 쉘로 진입 (하단 네비 포함)
                    _AnimatedPrimaryButton(
                      text: '앱 들어가기 (임시)',
                      gradientColors: const [Colors.orange, Colors.deepOrange],
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MainShell()),
                        );
                      },
                    ),
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

void _showEmailLoginSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) {
          return const EmailLoginForm();
        },
      );
    },
  );
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

        if (result['success'] == true) {
          if (!mounted) return;
          // UserProvider에 사용자 정보 저장
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          userProvider.setUser(
            userId: result['userId'],
            nickname: result['nickname'],
            accessToken: result['accessToken'],
            profileImageUrl: result['profileImageUrl'],
          );

          // 로그인 성공 시 화면 이동
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('로그인되었습니다!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('로그인 실패: $e'), backgroundColor: Colors.red),
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
                  hintText: '아이디/이메일 입력',
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
