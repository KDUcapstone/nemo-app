import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';

class EmailVerificationSection extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController codeController;
  final String? Function(String?) emailValidator;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyCode;
  final bool isSendingCode;
  final bool isVerifyingCode;
  final bool codeSent;
  final bool emailVerified;

  const EmailVerificationSection({
    super.key,
    required this.emailController,
    required this.codeController,
    required this.emailValidator,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.isSendingCode,
    required this.isVerifyingCode,
    required this.codeSent,
    required this.emailVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
            hintText: '이메일 입력',
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
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton(
            onPressed: isSendingCode ? null : onSendCode,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: isSendingCode
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  )
                : const Text('인증요청'),
          ),
        ),
        if (codeSent) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: codeController,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(
                      Icons.verified,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    hintText: '인증 코드 입력',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isVerifyingCode ? null : onVerifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: emailVerified
                        ? Colors.green
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: isVerifyingCode
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(emailVerified ? '인증완료' : '인증확인'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
