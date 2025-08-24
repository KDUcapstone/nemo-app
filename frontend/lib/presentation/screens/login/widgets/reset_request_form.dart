import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';

class ResetRequestForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final String? Function(String?) emailValidator;
  final VoidCallback onSubmit;
  final bool isLoading;

  const ResetRequestForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.emailValidator,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            validator: emailValidator,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(
                Icons.email_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 36,
              ),
              hintText: '이메일 주소 입력',
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 8,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.divider,
                  width: 1,
                ),
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
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
                  : const Text('재설정 링크 발송'),
            ),
          ),
        ],
      ),
    );
  }
}
