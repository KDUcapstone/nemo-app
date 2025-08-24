import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'glass_card.dart';
import 'icon_input_field.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

class ProfileCard extends StatelessWidget {
  final bool isEditing;
  final TextEditingController nicknameController;
  final String email;
  final String nickname;
  final String? profileImageUrl;
  final File? selectedImage;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onOpenImagePicker;

  const ProfileCard({
    super.key,
    required this.isEditing,
    required this.nicknameController,
    required this.email,
    required this.nickname,
    required this.profileImageUrl,
    required this.selectedImage,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
    required this.onOpenImagePicker,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: isEditing ? onOpenImagePicker : null,
            child: Stack(
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
                      : profileImageUrl != null
                      ? ClipOval(
                          child: Image.network(
                            profileImageUrl!,
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
                if (isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (isEditing)
            Column(
              children: [
                IconInputField(
                  hintText: '닉네임 입력 (2-10자)',
                  keyboardType: TextInputType.text,
                  icon: Icons.person_outline,
                  controller: nicknameController,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(text: '취소', onTap: onCancel),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(text: '저장', onTap: onSave),
                    ),
                  ],
                ),
              ],
            )
          else
            Column(
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(text: '정보 수정', onTap: onEdit),
              ],
            ),
        ],
      ),
    );
  }
}
