// 📁 lib/presentation/screens/login/signup_screen.dart
import 'dart:ui';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'login_screen.dart';
import 'widgets/email_verification_section.dart';
import 'package:frontend/services/auth_service.dart';
import 'signup_form_model.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isLoading = false;
  bool _emailCodeSent = false;
  bool _emailVerified = false;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    _emailCodeController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '이메일을 입력해주세요';
    }
    // 간단하고 표준적인 이메일 정규식 (문자열 끝은 $ 로 마감)
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) {
      return '올바른 이메일 형식을 입력해주세요';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요';
    }
    // 명세: 최소 8자, 특수문자 포함. 또한 영문과 숫자 포함을 권장
    if (value.length < 8) {
      return '비밀번호는 최소 8자 이상이어야 합니다';
    }
    // 하나 이상의 영문, 숫자, 특수문자 포함 체크
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(value);
    if (!(hasLetter && hasDigit && hasSpecial)) {
      return '영문, 숫자, 특수문자를 각각 1자 이상 포함해야 합니다';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호 확인을 입력해주세요';
    }
    if (value != _passwordController.text) {
      return '비밀번호가 일치하지 않습니다';
    }
    return null;
  }

  String? _validateNickname(String? value) {
    if (value == null || value.isEmpty) {
      return '닉네임을 입력해주세요';
    }
    if (value.length < 2) {
      return '닉네임은 2자 이상이어야 합니다';
    }
    if (value.length > 10) {
      return '닉네임은 10자 이하여야 합니다';
    }
    return null;
  }

  Future<void> _sendEmailCode() async {
    if (_validateEmail(_emailController.text) != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('유효한 이메일을 입력해주세요')));
      return;
    }
    setState(() {
      _isSendingCode = true;
    });
    try {
      await AuthService().sendEmailVerification(_emailController.text);
      if (!mounted) return;
      setState(() {
        _emailCodeSent = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증 메일을 발송했습니다. 메일함을 확인해주세요.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('인증 메일 발송 실패: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _verifyEmailCode() async {
    if (_emailCodeController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증 코드를 입력해주세요')));
      return;
    }
    setState(() {
      _isVerifyingCode = true;
    });
    try {
      final ok = await AuthService().confirmEmailVerification(
        email: _emailController.text.trim(),
        code: _emailCodeController.text.trim(),
      );
      if (!mounted) return;
      if (ok) {
        setState(() {
          _emailVerified = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이메일 인증이 완료되었습니다.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('인증 실패: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다')));
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진 촬영 중 오류가 발생했습니다')));
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '프로필 이미지 선택',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ImagePickerOption(
                    icon: Icons.camera_alt,
                    label: '카메라',
                    onTap: () {
                      Navigator.pop(context);
                      _takePhoto();
                    },
                  ),
                  _ImagePickerOption(
                    icon: Icons.photo_library,
                    label: '갤러리',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate() == false) return;
    if (_emailVerified == false) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일 인증을 먼저 완료해주세요')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 명세에 맞춘 회원가입 API 호출
      final ok = await AuthService().signup(
        SignupFormModel(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          nickname: _nicknameController.text.trim(),
        ),
      );

      if (mounted && ok) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('회원가입이 완료되었습니다!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('회원가입 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                      '회원가입',
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // 프로필 이미지 선택
                              _ProfileImageSelector(
                                selectedImage: _selectedImage,
                                onTap: _showImagePickerDialog,
                              ),
                              const SizedBox(height: 20),

                              // 닉네임 입력
                              _IconInputField(
                                hintText: '닉네임 입력 (2-10자)',
                                keyboardType: TextInputType.text,
                                icon: Icons.person_outline,
                                controller: _nicknameController,
                                validator: _validateNickname,
                              ),
                              const SizedBox(height: 12),

                              // 이메일 인증 섹션 (분리 위젯)
                              EmailVerificationSection(
                                emailController: _emailController,
                                codeController: _emailCodeController,
                                emailValidator: _validateEmail,
                                onSendCode: _sendEmailCode,
                                onVerifyCode: _verifyEmailCode,
                                isSendingCode: _isSendingCode,
                                isVerifyingCode: _isVerifyingCode,
                                codeSent: _emailCodeSent,
                                emailVerified: _emailVerified,
                              ),

                              const SizedBox(height: 12),

                              // 비밀번호 입력
                              _IconInputField(
                                hintText: '비밀번호 입력 (영문+숫자+특수문자, 8자 이상)',
                                obscureText: true,
                                icon: Icons.lock_outline,
                                controller: _passwordController,
                                validator: _validatePassword,
                              ),
                              const SizedBox(height: 12),

                              // 비밀번호 확인
                              _IconInputField(
                                hintText: '비밀번호 확인',
                                obscureText: true,
                                icon: Icons.lock_reset,
                                controller: _confirmPasswordController,
                                validator: _validateConfirmPassword,
                              ),
                              const SizedBox(height: 20),

                              // 회원가입 버튼 (인증 미완료 시 안내)
                              _PrimaryButton(
                                text: _isLoading ? '가입 중...' : '회원가입',
                                onTap: _isLoading
                                    ? () {}
                                    : () => _handleSignup(),
                                isLoading: _isLoading,
                              ),
                            ],
                          ),
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
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text.rich(
                        TextSpan(
                          text: '이미 회원이신가요? ',
                          children: [
                            TextSpan(
                              text: '로그인',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                          style: TextStyle(color: AppColors.textPrimary),
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

class _IconInputField extends StatefulWidget {
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData icon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextEditingController? controller;

  const _IconInputField({
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
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
      onChanged: widget.onChanged,
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
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.4),
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

class _ProfileImageSelector extends StatelessWidget {
  final File? selectedImage;
  final VoidCallback onTap;

  const _ProfileImageSelector({
    required this.selectedImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: selectedImage != null
                ? ClipOval(
                    child: Image.file(
                      selectedImage!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.person,
                    size: 50,
                    color: AppColors.textSecondary,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            '프로필 이미지 선택',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ImagePickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImagePickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
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
