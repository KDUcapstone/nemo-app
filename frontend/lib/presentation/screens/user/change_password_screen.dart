import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/providers/user_provider.dart';
import '../login/login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateCurrent(String? v) {
    if (v == null || v.isEmpty) return '현재 비밀번호를 입력해주세요';
    return null;
  }

  String? _validateNew(String? v) {
    if (v == null || v.isEmpty) return '새 비밀번호를 입력해주세요';
    if (v.length < 8 || v.length > 64) {
      return '비밀번호는 8~64자여야 합니다';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(v);
    final count = [hasLetter, hasDigit, hasSpecial].where((e) => e).length;
    if (count < 2) {
      return '영문/숫자/특수문자 중 2종 이상 포함해야 합니다';
    }
    if (v == _currentController.text) {
      return '현재 비밀번호와 달라야 합니다';
    }
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return '새 비밀번호 확인을 입력해주세요';
    if (v != _newController.text) return '새 비밀번호와 확인 값이 다릅니다';
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = AuthService();
      final msg = await auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
        confirmPassword: _confirmController.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('비밀번호 변경 완료'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      // 로그아웃 처리 및 로그인 화면으로 이동
      try {
        await auth.logout();
      } catch (_) {
        AuthService.clearAccessToken();
      }
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      String msg;
      if (s.contains('UNAUTHORIZED')) {
        msg = '로그인이 필요합니다.';
      } else if (s.contains('INVALID_CURRENT_PASSWORD')) {
        msg = '비밀번호가 틀렸습니다';
      } else if (s.contains('PASSWORD_CONFIRM_MISMATCH')) {
        msg = '새 비밀번호와 확인 값이 일치하지 않습니다.';
      } else if (s.contains('PASSWORD_POLICY_VIOLATION')) {
        msg = '비밀번호 정책을 만족하지 않습니다.';
      } else {
        // Exception: 접두사 제거
        if (s.startsWith('Exception: ')) {
          msg = s.substring('Exception: '.length);
        } else {
          msg = '비밀번호 변경에 실패했습니다.';
        }
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        title: Text('비밀번호 변경', style: GoogleFonts.jua(color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PasswordField(
                  label: '현재 비밀번호',
                  controller: _currentController,
                  obscure: !_showCurrent,
                  onToggle: () => setState(() => _showCurrent = !_showCurrent),
                  validator: _validateCurrent,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  label: '새 비밀번호',
                  controller: _newController,
                  obscure: !_showNew,
                  onToggle: () => setState(() => _showNew = !_showNew),
                  validator: _validateNew,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  label: '새 비밀번호 확인',
                  controller: _confirmController,
                  obscure: !_showConfirm,
                  onToggle: () => setState(() => _showConfirm = !_showConfirm),
                  validator: _validateConfirm,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          '비밀번호 변경',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}


