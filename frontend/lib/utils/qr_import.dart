import 'package:flutter/material.dart';
import 'package:frontend/services/photo_upload_api.dart';
import 'package:frontend/presentation/screens/photo/photo_add_detail_screen.dart';

/// QR 코드를 스캔한 후 임시 등록 API 호출하고 상세정보 입력 화면으로 이동
/// 명세서: POST /api/photos/qr-import - QR 코드로 이미지 가져오기 + 미리보기용 imageUrl 반환
Future<void> handleQrImport(BuildContext context, String qrCode) async {
  if (qrCode.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QR 코드가 비어있습니다.')));
    }
    return;
  }

  if (!context.mounted) return;

  // 로딩 표시
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // QR 임시 등록 API 호출
    final api = PhotoUploadApi();
    final result = await api.importPhotoFromQr(qrCode: qrCode);

    if (!context.mounted) return;

    // 로딩 닫기
    Navigator.pop(context);

    // 상세정보 입력 화면으로 이동 (photoId, imageUrl 등 포함)
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoAddDetailScreen(
          imageFile: null,
          qrCode: qrCode,
          qrImportResult:
              result, // photoId, imageUrl, takenAt, location, brand, status 포함
          defaultTakenAt: result['takenAt'] != null
              ? DateTime.tryParse(result['takenAt'] as String)
              : DateTime.now(),
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;

    // 로딩 닫기
    Navigator.pop(context);

    // 에러 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }
}
