import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/providers/user_provider.dart';
import '../forgot_password_screen.dart';
import '../signup_screen.dart';

class EmailLoginForm extends StatefulWidget {
  const EmailLoginForm({super.key});

  @override
  State<EmailLoginForm> createState() => _EmailLoginFormState();
}

class _EmailLoginFormState extends State<EmailLoginForm> {
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
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$');
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

        if (result['success'] == true && mounted) {
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

          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: $e'), backgroundColor: Colors.red),
        );
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
  final void Function(String)? onChanged;
  final TextEditingController? controller;

  const _IconInputField({
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.strongBorder = false,
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
        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.9)),
        filled: true,
        fillColor: widget.strongBorder
            ? Colors.white
            : Colors.white.withOpacity(0.28),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: widget.strongBorder
                ? AppColors.divider
                : Colors.white.withOpacity(0.5),
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

  const _PrimaryButton({required this.text, required this.onTap});

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
