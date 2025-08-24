import 'package:flutter/material.dart';
import '../qr/qr_scanner_screen.dart';

// 업로드 화면을 QR 스캐너로 대체. 호환 경로를 위해 래퍼 위젯 제공
class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const QrScannerScreen();
  }
}
