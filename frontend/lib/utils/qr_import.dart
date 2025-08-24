import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:frontend/services/photo_upload_api.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/photo_provider.dart';

/// QR 페이로드를 받아 사진을 다운로드하고 업로드까지 수행하는 공용 유틸
Future<void> handleQrImport(BuildContext context, String payload) async {
  final match = RegExp(r'https?://[^\s]+').firstMatch(payload);
  if (match == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('지원되지 않는 QR 형식입니다.')));
    return;
  }
  final url = match.group(0)!;

  try {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
      final Uint8List bytes = resp.bodyBytes;
      final tempDir = Directory.systemTemp;
      final fileName = 'qr_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = p.join(tempDir.path, fileName);
      final file = await File(filePath).writeAsBytes(bytes);

      final nowIso = DateFormat("yyyy-MM-ddTHH:mm:ss").format(DateTime.now());
      final api = PhotoUploadApi();
      final result = await api.uploadPhotoViaQr(
        qrCode: payload,
        imageFile: file,
        takenAtIso: nowIso,
        location: '포토부스(추정)',
        brand: '인생네컷',
        tagList: const ['QR업로드'],
        friendIdList: const [],
      );

      if (!context.mounted) return;
      // 상태 반영 (목록 갱신)
      context.read<PhotoProvider>().addFromResponse(result);
      // 성공 알림
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 완료 (ID: ${result['photoId']})')),
      );
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지를 불러오지 못했습니다 (${resp.statusCode})')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('가져오기 실패: $e')));
    }
  }
}
