import 'package:flutter/material.dart';
import 'package:frontend/services/photo_upload_api.dart';
import 'package:frontend/presentation/screens/photo/photo_add_detail_screen.dart';
import 'package:frontend/services/photo_api.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/photo_provider.dart';

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
    final uploadApi = PhotoUploadApi();
    final result = await uploadApi.importPhotoFromQr(qrCode: qrCode);

    if (!context.mounted) return;

    // 로딩 닫기
    Navigator.pop(context);

    final tempPhotoId = result['photoId'] as int?;

    // 상세정보 입력 화면으로 이동 (photoId, imageUrl 등 포함)
    final success = await Navigator.push<bool>(
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

    if (!context.mounted) return;

    // 상세정보 입력에서 실제로 "추가"를 완료한 경우(true 반환)만 사진을 유지
    // 그 외(null/false/뒤로가기)는 임시 등록된 사진을 정리
    if (success != true && tempPhotoId != null) {
      try {
        final photoApi = PhotoApi();
        await photoApi.deletePhoto(tempPhotoId);

        // 이미 목록이 로드된 경우 PhotoProvider에서도 제거
        try {
          context.read<PhotoProvider>().removeById(tempPhotoId);
        } catch (_) {
          // PhotoProvider가 없는 컨텍스트일 수 있으므로 무시
        }
      } catch (_) {
        // 삭제 실패 시에는 사용자에게 별도 노출 없이 무시
      }
    }
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
