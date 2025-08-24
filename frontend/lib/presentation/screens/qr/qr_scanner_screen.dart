import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  bool _torchEnabled = false;
  bool _isBackCamera = true;
  bool _isHandling = false; // 중복 인식 방지
  final ImagePicker _picker = ImagePicker();
  double _zoom = 1.0; // 1.0 ~ 1.x (controller 내부 스케일로 전달)
  double _zoomBaseOnPinch = 1.0;
  bool _isPinching = false;
  bool _isSwitching = false;
  bool _isDisposed = false;
  DateTime? _lastZoomAppliedAt;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: [BarcodeFormat.qrCode],
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    if (_isDisposed || _isSwitching) return;
    try {
      await _controller.toggleTorch();
      final state = _controller.torchState.value;
      if (mounted) setState(() => _torchEnabled = state == TorchState.on);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    try {
      _isSwitching = true;
      await _controller.switchCamera();
      if (mounted) setState(() => _isBackCamera = !_isBackCamera);
    } catch (_) {
    } finally {
      _isSwitching = false;
    }
  }

  Future<void> _openGalleryAndScan() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      // mobile_scanner 3.x: 이미지 파일 분석 지원
      final bool ok = await _controller.analyzeImage(file.path);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지에서 QR을 인식하지 못했습니다.')),
          );
        }
        return;
      }
      // analyzeImage가 성공하면 onDetect 콜백이 호출되어 _onDetect에서 처리됩니다.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('갤러리 스캔 실패: $e')));
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isHandling || _isSwitching) return;
    final codes = capture.barcodes;
    if (codes.isEmpty) return;
    final value = codes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _isHandling = true;
    if (mounted) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (details) {
                  if (details.pointerCount >= 2) {
                    _isPinching = true;
                    _zoomBaseOnPinch = _zoom;
                  }
                },
                onScaleUpdate: (details) async {
                  if (_isDisposed || _isSwitching) return;
                  if (!_isPinching || details.pointerCount < 2) return;
                  // 핀치 배율을 현재 줌에 곱해 반영 (1.0~4.0)
                  final next = (_zoomBaseOnPinch * details.scale).clamp(
                    1.0,
                    4.0,
                  );
                  if (next == _zoom) return;
                  _zoom = next;
                  try {
                    // 1.0~4.0 -> 0.0~1.0 선형 매핑
                    final scale = ((_zoom - 1.0) / 3.0)
                        .clamp(0.0, 1.0)
                        .toDouble();
                    // 호출 쓰로틀링(약 40ms)
                    final now = DateTime.now();
                    if (_lastZoomAppliedAt == null ||
                        now.difference(_lastZoomAppliedAt!) >
                            const Duration(milliseconds: 40)) {
                      _lastZoomAppliedAt = now;
                      await _controller.setZoomScale(scale);
                    }
                  } catch (_) {}
                },
                onScaleEnd: (_) {
                  _isPinching = false;
                },
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
              ),
            ),
            // 상단 우측: 플래시/카메라 전환
            Positioned(
              right: 16,
              top: 16,
              child: Row(
                children: [
                  ValueListenableBuilder<TorchState>(
                    valueListenable: _controller.torchState,
                    builder: (context, state, _) {
                      final isOn = state == TorchState.on;
                      return IconButton(
                        onPressed: _toggleTorch,
                        color: Colors.white,
                        icon: Icon(
                          isOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    onPressed: _switchCamera,
                    color: Colors.white,
                    icon: const Icon(Icons.cameraswitch_rounded),
                  ),
                ],
              ),
            ),
            // 중앙 가이드 박스
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // 좌하단: 갤러리 버튼
            Positioned(
              left: 16,
              bottom: 24,
              child: ElevatedButton.icon(
                onPressed: _openGalleryAndScan,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('갤러리'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            // 하단 안내
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: Column(
                children: const [
                  Text(
                    'QR 코드를 가이드 박스 안에 맞춰주세요',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
