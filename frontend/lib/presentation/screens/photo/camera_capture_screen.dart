import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;
  bool _isInitializing = true;
  bool _isTakingPicture = false;
  bool _isSwitchingCamera = false;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('사용 가능한 카메라가 없습니다.');
      }
      _selectedCameraIndex = 0; // 기본 후면 카메라
      _controller = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      // 초기 플래시 모드 설정 (지원 안 하면 무시)
      try {
        await _controller!.setFlashMode(_flashMode);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _isInitializing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isInitializing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카메라 초기화 실패: $e')));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('전/후면 카메라가 하나만 있습니다.')));
      }
      return;
    }
    if (_isSwitchingCamera) return;
    setState(() {
      _isSwitchingCamera = true;
      _isInitializing = true;
    });
    try {
      final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
      await _controller?.dispose();
      _controller = CameraController(
        _cameras[newIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      _selectedCameraIndex = newIndex;
      await _controller!.initialize();
      try {
        await _controller!.setFlashMode(_flashMode);
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('카메라 전환 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isSwitchingCamera = false;
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isTakingPicture) return;
    setState(() => _isTakingPicture = true);
    try {
      // 촬영 직전에 현재 플래시 모드를 다시 적용 (일부 기기에서 필요)
      try {
        await _controller!.setFlashMode(
          _isBackCamera() ? _flashMode : FlashMode.off,
        );
      } catch (_) {}
      final XFile file = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.pop(context, File(file.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('촬영 실패: $e')));
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  Future<void> _openGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null && mounted) {
      Navigator.pop(context, File(file.path));
    }
  }

  void _cycleFlashMode() async {
    if (_controller == null) return;
    if (!_isBackCamera()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전면 카메라는 플래시를 지원하지 않습니다.')),
        );
      }
      return;
    }
    final modes = [
      FlashMode.off,
      FlashMode.auto,
      FlashMode.always,
      FlashMode.torch,
    ];
    final nextIndex = (modes.indexOf(_flashMode) + 1) % modes.length;
    final nextMode = modes[nextIndex];
    try {
      await _controller!.setFlashMode(nextMode);
      if (mounted) {
        setState(() => _flashMode = nextMode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('플래시 설정 실패: $e')));
      }
    }
  }

  IconData _flashIcon(FlashMode mode) {
    switch (mode) {
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.torch:
        return Icons.bolt_rounded;
      case FlashMode.off:
        return Icons.flash_off_rounded;
    }
  }

  bool _isBackCamera() {
    if (_cameras.isEmpty) return false;
    return _cameras[_selectedCameraIndex].lensDirection ==
        CameraLensDirection.back;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isInitializing || _controller == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(child: CameraPreview(_controller!)),
                  // 상단 우측: 플래시 모드 토글
                  if (_isBackCamera())
                    Positioned(
                      right: 16,
                      top: 16,
                      child: GestureDetector(
                        onTap: _cycleFlashMode,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white54),
                          ),
                          child: Icon(
                            _flashIcon(_flashMode),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  // 하단 컨트롤 바
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 좌하단: 갤러리 진입 버튼(썸네일 스타일)
                        GestureDetector(
                          onTap: _openGallery,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white54),
                            ),
                            child: const Icon(
                              Icons.photo_library_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                        // 중앙: 촬영 버튼
                        GestureDetector(
                          onTap: _isTakingPicture ? null : _takePicture,
                          child: Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        // 우하단: 카메라 전환
                        GestureDetector(
                          onTap: _switchCamera,
                          child: const CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white24,
                            child: Icon(
                              Icons.cameraswitch_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
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
