import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';

class PasswordResetForm extends StatefulWidget {
  final Future<void> Function(String newPassword, String confirmPassword)
  onSubmit;
  final bool isLoading;

  const PasswordResetForm({
    super.key,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  State<PasswordResetForm> createState() => _PasswordResetFormState();
}

class _PasswordResetFormState extends State<PasswordResetForm> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요';
    }
    if (value.length < 8 || value.length > 64) {
      return '8~64자 사이로 입력해주세요';
    }
    // 영문, 숫자, 특수문자 중 2종 이상 포함
    int types = 0;
    if (RegExp(r'[A-Za-z]').hasMatch(value)) types++;
    if (RegExp(r'\d').hasMatch(value)) types++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) types++;

    if (types < 2) {
      return '영문, 숫자, 특수문자 중 2가지 이상을 포함해야 합니다';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '새 비밀번호 설정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 비밀번호를 입력해주세요.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _PasswordField(
            controller: _newPasswordController,
            hintText: '새 비밀번호',
            obscureText: _obscureNew,
            onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
            validator: _validatePassword,
          ),
          const SizedBox(height: 12),
          _PasswordField(
            controller: _confirmPasswordController,
            hintText: '새 비밀번호 확인',
            obscureText: _obscureConfirm,
            onToggleObscure: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            validator: (value) {
              if (value != _newPasswordController.text) {
                return '비밀번호가 일치하지 않습니다';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.isLoading
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSubmit(
                          _newPasswordController.text,
                          _confirmPasswordController.text,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '비밀번호 변경',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.onToggleObscure,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(
          Icons.lock_outline,
          size: 20,
          color: AppColors.textSecondary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: onToggleObscure,
        ),
        hintText: hintText,
        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.4),
        ),
      ),
    );
  }
}
