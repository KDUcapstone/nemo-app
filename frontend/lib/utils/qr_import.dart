import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:frontend/presentation/screens/photo/photo_add_detail_screen.dart';

/// QR 페이로드를 받아 사진을 다운로드하고 상세정보 입력 화면으로 이동
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
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final resp = await http.get(Uri.parse(url));
    if (Navigator.canPop(context)) {
      Navigator.pop(context); // 로딩 닫기
    }
    
    if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
      final Uint8List bytes = resp.bodyBytes;
      final tempDir = Directory.systemTemp;
      final fileName = 'qr_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = p.join(tempDir.path, fileName);
      final file = await File(filePath).writeAsBytes(bytes);

      // 파일이 제대로 저장되었는지 확인
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('파일 저장에 실패했습니다.')),
          );
        }
        return;
      }

      // 파일 크기 확인 (비어있지 않은지)
      final fileLength = await file.length();
      if (fileLength == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 파일이 비어있습니다.')),
          );
        }
        return;
      }

      if (!context.mounted) return;
      
      // 상세정보 입력 화면으로 이동
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoAddDetailScreen(
            imageFile: file,
            qrCode: payload,
            defaultTakenAt: DateTime.now(),
          ),
        ),
      );
      
      if (success == true && context.mounted) {
        // 성공적으로 추가된 경우 (화면에서 이미 알림 표시)
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지를 불러오지 못했습니다 (${resp.statusCode})')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      // 로딩이 열려있을 수 있으므로 닫기
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('가져오기 실패: $e')));
    }
  }
}
