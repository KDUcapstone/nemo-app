import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/presentation/screens/photo/photo_detail_screen.dart'
    show DetailSheetModal;

/// 타임라인 사진 스토리 뷰어 화면
/// 인스타그램 스토리처럼 한장씩 스와이프로 넘길 수 있음
class TimelinePhotoStoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  const TimelinePhotoStoryScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  @override
  State<TimelinePhotoStoryScreen> createState() =>
      _TimelinePhotoStoryScreenState();
}

class _TimelinePhotoStoryScreenState extends State<TimelinePhotoStoryScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  Timer? _autoAdvanceTimer;
  bool _isPaused = false;
  late AnimationController _progressController;
  static const Duration _autoAdvanceDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: _autoAdvanceDuration,
    );
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _progressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _pauseAutoAdvance() {
    if (_isPaused) return; // 이미 일시정지 중이면 무시
    setState(() {
      _isPaused = true;
    });
    _autoAdvanceTimer?.cancel();
    // 진행 바 애니메이션 일시정지
    _progressController.stop();
  }

  void _resumeAutoAdvance() {
    if (!_isPaused) return; // 일시정지 중이 아니면 무시
    setState(() {
      _isPaused = false;
    });
    // 남은 시간 계산
    final elapsed =
        (_progressController.value * _autoAdvanceDuration.inMilliseconds)
            .round();
    final remaining = _autoAdvanceDuration.inMilliseconds - elapsed;

    if (remaining > 0 && mounted) {
      // 남은 시간에 맞게 애니메이션 duration 조정
      final currentValue = _progressController.value;
      final remainingValue = 1.0 - currentValue;
      final adjustedDuration = Duration(
        milliseconds: (remainingValue * _autoAdvanceDuration.inMilliseconds)
            .round(),
      );

      // 애니메이션 컨트롤러를 남은 시간에 맞게 조정
      _progressController.duration = adjustedDuration;

      // 남은 시간만큼 타이머 시작
      _autoAdvanceTimer = Timer(Duration(milliseconds: remaining), () {
        if (!_isPaused && mounted) {
          if (_currentIndex < widget.photos.length - 1) {
            // 다음 사진으로 넘어가기 전에 duration을 원래대로 복원
            _progressController.duration = _autoAdvanceDuration;
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          } else {
            // 마지막 사진이면 진행 바 완료 후 화면 닫기
            _progressController.duration =
                _autoAdvanceDuration; // 원래 duration으로 복원
            _progressController.forward().then((_) {
              if (mounted) {
                Navigator.pop(context);
              }
            });
          }
        }
      });
      // 진행 바 애니메이션 재개 (현재 값부터 계속)
      _progressController.forward();
    } else {
      // 시간이 이미 다 지났으면 바로 다음 사진으로 또는 화면 닫기
      _progressController.duration = _autoAdvanceDuration; // 원래 duration으로 복원
      _progressController.forward();
      if (_currentIndex < widget.photos.length - 1 && mounted) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (mounted) {
        // 마지막 사진이면 화면 닫기
        Navigator.pop(context);
      }
    }
  }

  void _startAutoAdvance() {
    if (widget.photos.length <= 1) return;

    _autoAdvanceTimer?.cancel();
    if (_isPaused) return; // 일시정지 중이면 시작하지 않음

    // 진행 바 애니메이션 시작
    _progressController.reset();
    _progressController.forward();

    _autoAdvanceTimer = Timer(_autoAdvanceDuration, () {
      if (!_isPaused && mounted) {
        if (_currentIndex < widget.photos.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          // 마지막 사진이면 진행 바 완료 후 화면 닫기
          _progressController.forward().then((_) {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    // 스와이프로 넘겼으므로 자동 넘기기 재시작
    _autoAdvanceTimer?.cancel();
    _progressController.stop();
    _progressController.reset();
    // duration을 원래대로 복원
    _progressController.duration = _autoAdvanceDuration;
    // 마지막 사진에서도 시간이 흘러가도록 시작
    _startAutoAdvance();
  }

  void _showPhotoDetailSheet(int photoId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DetailSheetModal(photoId: photoId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text('사진이 없습니다.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 사진 뷰어
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.photos.length,
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              final imageUrl = photo['imageUrl'] as String;
              final isFile =
                  imageUrl.isNotEmpty && !imageUrl.startsWith('http');

              return GestureDetector(
                onLongPressStart: (_) {
                  // 길게 누르기 시작: 자동 넘기기 일시정지
                  _pauseAutoAdvance();
                },
                onLongPressEnd: (_) {
                  // 길게 누르기 끝: 자동 넘기기 재개
                  _resumeAutoAdvance();
                },
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null) {
                    // 위로 스와이프 (음수 velocity = 위로)
                    if (details.primaryVelocity! < -300) {
                      _autoAdvanceTimer?.cancel();
                      _progressController.stop();
                      _showPhotoDetailSheet(photo['photoId'] as int);
                    }
                    // 아래로 스와이프 (양수 velocity = 아래로)
                    else if (details.primaryVelocity! > 300) {
                      _autoAdvanceTimer?.cancel();
                      _progressController.stop();
                      Navigator.pop(context);
                    }
                  }
                },
                child: Stack(
                  children: [
                    // 이미지
                    InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      panEnabled: false, // 좌우 스와이프를 PageView가 처리하도록 비활성화
                      child: Center(
                        child: isFile
                            ? Image.file(
                                File(imageUrl),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[900],
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.white54,
                                      size: 64,
                                    ),
                                  ),
                                ),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      );
                                    },
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[900],
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.white54,
                                      size: 64,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    // 왼쪽 절반 (이전 사진으로)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: MediaQuery.of(context).size.width / 2,
                      child: GestureDetector(
                        onTap: () {
                          // 왼쪽 탭: 이전 사진으로 (현재 인덱스가 0보다 클 때만)
                          if (_currentIndex > 0) {
                            _autoAdvanceTimer?.cancel();
                            _progressController.stop();
                            _progressController.reset();
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    // 오른쪽 절반 (다음 사진으로 또는 닫기)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: MediaQuery.of(context).size.width / 2,
                      child: GestureDetector(
                        onTap: () {
                          // 오른쪽 탭: 다음 사진으로 또는 마지막이면 닫기
                          if (_currentIndex < widget.photos.length - 1) {
                            _autoAdvanceTimer?.cancel();
                            _progressController.stop();
                            _progressController.reset();
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            // 마지막 사진에서 오른쪽을 누르면 닫기
                            _autoAdvanceTimer?.cancel();
                            _progressController.stop();
                            Navigator.pop(context);
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // 상단 진행 바 (여러장일 때)
          if (widget.photos.length > 1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: List.generate(
                      widget.photos.length,
                      (index) => Expanded(
                        child: Container(
                          height: 3,
                          margin: EdgeInsets.only(
                            right: index < widget.photos.length - 1 ? 4 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white38,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Stack(
                            children: [
                              // 진행 바 배경
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white38,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // 채워지는 진행 바
                              if (index == _currentIndex)
                                AnimatedBuilder(
                                  animation: _progressController,
                                  builder: (context, child) {
                                    return FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _progressController.value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              else if (index < _currentIndex)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 상단 UI (닫기)
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 48, 12, 0),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 단일 사진 전체화면 뷰어
class TimelinePhotoFullscreenScreen extends StatelessWidget {
  final Map<String, dynamic> photo;
  const TimelinePhotoFullscreenScreen({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    final imageUrl = photo['imageUrl'] as String;
    final isFile = imageUrl.isNotEmpty && !imageUrl.startsWith('http');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                // 위로 스와이프하면 상세 정보 바텀시트 열기
                if (details.primaryVelocity! < -300) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    isDismissible: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        DetailSheetModal(photoId: photo['photoId'] as int),
                  );
                }
                // 아래로 스와이프하면 화면 닫기
                else if (details.primaryVelocity! > 300) {
                  Navigator.pop(context);
                }
              }
            },
            onTap: () {
              Navigator.pop(context);
            },
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: isFile
                    ? Image.file(
                        File(imageUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.white54,
                              size: 64,
                            ),
                          ),
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.white54,
                              size: 64,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          // 닫기 버튼
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
