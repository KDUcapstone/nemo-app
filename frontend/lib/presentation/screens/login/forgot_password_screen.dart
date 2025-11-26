// 📁 lib/presentation/screens/login/forgot_password_screen.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/services/auth_service.dart';
import 'login_screen.dart';
import 'widgets/reset_info_card.dart';
import 'widgets/reset_request_form.dart';
import 'widgets/code_verification_form.dart';
import 'widgets/password_reset_form.dart';
import 'widgets/reset_success_card.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();

  // State for the 3-step flow
  int _currentStep = 0; // 0: Email, 1: Code, 2: Reset, 3: Success
  bool _isLoading = false;

  // Data
  String _email = '';
  String _resetToken = '';

  // Step 0: Email Input
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // Step 1: Send Code
  Future<void> _sendResetCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text;
      final message = await _authService.sendPasswordResetCode(email);

      setState(() {
        _email = email;
        _currentStep = 1; // Move to Code Verification
        _isLoading = false;
      });
      _showSuccess(message);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Step 2: Verify Code
  Future<void> _verifyCode(String code) async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.verifyPasswordResetCode(
        email: _email,
        code: code,
      );

      if (result['verified'] == true) {
        setState(() {
          _resetToken = result['resetToken'];
          _currentStep = 2; // Move to Password Reset
          _isLoading = false;
        });
        _showSuccess('인증이 완료되었습니다.');
      } else {
        throw Exception('인증에 실패했습니다.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _resendCode() async {
    try {
      await _authService.sendPasswordResetCode(_email);
      _showSuccess('인증코드를 다시 전송했습니다.');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Step 3: Reset Password
  Future<void> _resetPassword(
    String newPassword,
    String confirmPassword,
  ) async {
    setState(() => _isLoading = true);
    try {
      final message = await _authService.resetPassword(
        resetToken: _resetToken,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      setState(() {
        _currentStep = 3; // Move to Success
        _isLoading = false;
      });
      _showSuccess(message);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SkyBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      child: _Logo(),
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
                    const SizedBox(height: 10),
                    Text(
                      '비밀번호 재설정',
                      style: GoogleFonts.jua(
                        fontSize: 28,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      child: _GlassCard(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _buildStepContent(),
                        ),
                      ),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 10),
                            child: child,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    if (_currentStep != 3)
                      TextButton(
                        onPressed: () {
                          if (_currentStep > 0) {
                            // Go back to previous step
                            setState(() {
                              _currentStep--;
                            });
                          } else {
                            _goToLogin();
                          }
                        },
                        child: Text.rich(
                          TextSpan(
                            text: _currentStep > 0 ? '이전 단계로' : '로그인으로 돌아가기',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
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

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          key: const ValueKey('step0'),
          children: [
            const ResetInfoCard(),
            const SizedBox(height: 20),
            ResetRequestForm(
              formKey: _emailFormKey,
              emailController: _emailController,
              emailValidator: _validateEmail,
              onSubmit: _sendResetCode,
              isLoading: _isLoading,
            ),
          ],
        );
      case 1:
        return CodeVerificationForm(
          key: const ValueKey('step1'),
          email: _email,
          onVerify: _verifyCode,
          onResend: _resendCode,
          isLoading: _isLoading,
        );
      case 2:
        return PasswordResetForm(
          key: const ValueKey('step2'),
          onSubmit: _resetPassword,
          isLoading: _isLoading,
        );
      case 3:
        return Column(
          key: const ValueKey('step3'),
          children: [
            const ResetSuccessCard(),
            const SizedBox(height: 20),
            _PrimaryButton(
              text: '로그인으로 이동',
              onTap: _goToLogin,
              isLoading: false,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color.fromARGB(137, 29, 29, 29),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.grid_view_rounded,
        size: 120,
        color: Color(0xFFCBD9F5),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;

  const _PrimaryButton({
    required this.text,
    required this.onTap,
    required this.isLoading,
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
            colors: [
              AppColors.primary.withOpacity(0.95),
              AppColors.primary.withOpacity(0.75),
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
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Text(
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

class _SkyBackground extends StatelessWidget {
  const _SkyBackground();

  @override
  Widget build(BuildContext context) {
    return _SkyBackgroundAnimated();
  }
}

class _SkyBackgroundAnimated extends StatefulWidget {
  @override
  State<_SkyBackgroundAnimated> createState() => _SkyBackgroundAnimatedState();
}

class _SkyBackgroundAnimatedState extends State<_SkyBackgroundAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;
          final dx1 = 6 * math.sin(t);
          final dy1 = 4 * math.cos(t);
          final dx2 = 8 * math.cos(t * 0.8);
          final dy2 = 5 * math.sin(t * 0.8);
          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.skyLight, AppColors.skyMid],
                  ),
                ),
              ),
              Positioned(
                top: -40 + dy1,
                right: -20 + dx1,
                child: Opacity(
                  opacity: 0.35,
                  child: _Blob(size: 160, color: AppColors.accent),
                ),
              ),
              Positioned(
                bottom: -50 + dy2,
                left: -20 + dx2,
                child: Opacity(
                  opacity: 0.25,
                  child: _Blob(size: 200, color: AppColors.skyDeep),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color),
        ),
      ),
    );
  }
}
