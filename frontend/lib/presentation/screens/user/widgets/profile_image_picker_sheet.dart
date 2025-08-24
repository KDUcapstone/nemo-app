import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'image_picker_option.dart';

class ProfileImagePickerSheet extends StatelessWidget {
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;

  const ProfileImagePickerSheet({
    super.key,
    required this.onTakePhoto,
    required this.onPickGallery,
  });

  @override
  Widget build(BuildContext context) {
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
              ImagePickerOption(
                icon: Icons.camera_alt,
                label: '카메라',
                onTap: () {
                  Navigator.pop(context);
                  onTakePhoto();
                },
              ),
              ImagePickerOption(
                icon: Icons.photo_library,
                label: '갤러리',
                onTap: () {
                  Navigator.pop(context);
                  onPickGallery();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
