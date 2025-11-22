import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/services/photo_upload_api.dart';
import 'package:frontend/providers/photo_provider.dart';

/// QR 페이로드를 받아 서버에 URL만 전달하여 임시 등록
/// API 명세서: POST /api/photos/qr-import - QR 코드만 받아서 백엔드가 사진을 가져옴
Future<void> handleQrImport(BuildContext context, String payload) async {
  final match = RegExp(r'https?://[^\s]+').firstMatch(payload);
  if (match == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('지원되지 않는 QR 형식입니다.')));
    return;
  }
  final sourceUrl = match.group(0)!;

  try {
    final api = PhotoUploadApi();
    // API 명세서: QR 임시 등록 API 사용 (qrCode만 전달)
    final result = await api.importPhotoFromQr(qrCode: sourceUrl);

    if (!context.mounted) return;

    // 임시 등록 후 상세정보 입력 화면으로 이동하거나, 바로 추가
    // photoId, imageUrl, takenAt, location, brand, status 포함
    context.read<PhotoProvider>().addFromResponse(result);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('QR 임시 등록 완료 (ID: ${result['photoId']})')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('가져오기 실패: $e')));
  }
}
