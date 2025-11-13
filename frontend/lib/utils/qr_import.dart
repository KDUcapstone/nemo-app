import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend/services/photo_upload_api.dart';
import 'package:frontend/providers/photo_provider.dart';

/// QR 페이로드를 받아 서버에 URL만 전달하여 업로드
Future<void> handleQrImport(BuildContext context, String payload) async {
  final match = RegExp(r'https?://[^\s]+').firstMatch(payload);
  if (match == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('지원되지 않는 QR 형식입니다.')));
    return;
  }
  final sourceUrl = match.group(0)!;

  try {
    final nowIso = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now());

    final api = PhotoUploadApi();
    final result = await api.uploadPhotoViaQr(
      qrCode: sourceUrl,
      takenAtIso: nowIso,
      location: '포토부스(추정)',
      brand: '인생네컷', // 필요 시 비워도 서버가 추론
      tagList: const ['QR업로드'],
      friendIdList: const [],
      // imageFile: null // (호환 파라미터, 명시 불필요)
    );

    if (!context.mounted) return;
    context.read<PhotoProvider>().addFromResponse(result);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('업로드 완료 (ID: ${result['photoId']})')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('가져오기 실패: $e')),
    );
  }
}
