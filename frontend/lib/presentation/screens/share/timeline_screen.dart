import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/services/timeline_api.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:frontend/presentation/screens/share/timeline_photo_story_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final TimelineApi _api = TimelineApi();
  final ScrollController _scrollController = ScrollController();

  // 캘린더 타임랩스 데이터 (날짜별 썸네일 정보)
  Map<String, Map<String, dynamic>> _timelapseData = {};

  // 타임라인 데이터 (날짜별 사진 목록)
  Map<String, List<Map<String, dynamic>>> _timelineData = {};

  DateTime? _joinDate;
  bool _loadingUserInfo = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfoAndInitialize();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 사용자 정보를 로드하여 가입일을 확인하고 캘린더 초기화
  Future<void> _loadUserInfoAndInitialize() async {
    try {
      final authService = AuthService();
      final userInfo = await authService.getUserInfo();

      if (!mounted) return;

      // 가입일 파싱
      final createdAt = userInfo['createdAt'];
      DateTime? joinDate;
      if (createdAt != null) {
        try {
          if (createdAt is String) {
            joinDate = DateTime.parse(createdAt);
          } else if (createdAt is int) {
            // epoch milliseconds
            joinDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
          }
          // 월의 시작일로 정규화
          if (joinDate != null) {
            joinDate = DateTime(joinDate.year, joinDate.month, 1);
          }
        } catch (_) {
          // 파싱 실패 시 현재 월로부터 12개월 전을 기본값으로 사용
        }
      }

      // 기본값: 현재 월로부터 12개월 전
      final now = DateTime.now();
      final defaultJoinDate = DateTime(now.year, now.month - 11, 1);

      setState(() {
        _joinDate = joinDate ?? defaultJoinDate;
        _loadingUserInfo = false;
      });

      // 현재 월 데이터 로드
      await _loadTimelapseForMonth(now.year, now.month);
      await _loadRecentTimeline();

      // 현재 월로 스크롤 (맨 위에 표시되도록)
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentMonth();
        });
      }
    } catch (e) {
      if (!mounted) return;
      // 에러 발생 시 기본값 사용
      final now = DateTime.now();
      setState(() {
        _joinDate = DateTime(now.year, now.month - 11, 1);
        _loadingUserInfo = false;
      });
      await _loadTimelapseForMonth(now.year, now.month);
      await _loadRecentTimeline();

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentMonth();
        });
      }
    }
  }

  /// 현재 월로 스크롤 (맨 위로)
  void _scrollToCurrentMonth() {
    if (!_scrollController.hasClients) return;

    // reverse 모드가 아니므로 스크롤을 맨 위(0)로 설정
    // 현재 월이 index 0이므로 자동으로 맨 위에 표시됨
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    });
  }

  /// 특정 월의 타임랩스 데이터 로드 (캘린더 표시용)
  Future<void> _loadTimelapseForMonth(int year, int month) async {
    if (!mounted) return;
    try {
      final data = await _api.getTimelapse(year: year, month: month);
      if (!mounted) return;
      setState(() {
        for (final item in data) {
          final date = item['date'] as String;
          _timelapseData[date] = item;
        }
      });
    } catch (e) {
      if (!mounted) return;
      // 에러는 조용히 처리 (lazy loading 중일 수 있음)
    }
  }

  /// 최근 타임라인 데이터 로드
  Future<void> _loadRecentTimeline() async {
    try {
      final data = await _api.getTimeline();
      if (!mounted) return;
      setState(() {
        _timelineData.clear();
        for (final item in data) {
          final date = item['date'] as String;
          final photos = (item['photos'] as List).cast<Map<String, dynamic>>();
          _timelineData[date] = photos;
        }
      });
    } catch (e) {
      if (!mounted) return;
      // 에러는 조용히 처리 (첫 로딩 시)
    }
  }

  /// 특정 날짜의 사진 목록 로드 및 뷰어 화면 표시
  Future<void> _loadPhotosForDate(DateTime date) async {
    final dateKey = _getDateKey(date);
    List<Map<String, dynamic>> photos;

    // 이미 로드된 데이터가 있으면 사용
    if (_timelineData.containsKey(dateKey)) {
      photos = _timelineData[dateKey]!;
    } else {
      // 데이터가 없으면 로드
      try {
        final data = await _api.getTimeline(year: date.year, month: date.month);
        if (!mounted) return;
        setState(() {
          for (final item in data) {
            final d = item['date'] as String;
            final photoList = (item['photos'] as List)
                .cast<Map<String, dynamic>>();
            _timelineData[d] = photoList;
          }
        });
        photos = _timelineData[dateKey] ?? [];
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다: $e')));
        return;
      }
    }

    if (!mounted) return;

    // 사진이 없으면 아무 일도 하지 않음
    if (photos.isEmpty) {
      return;
    }

    // 사진이 있으면 뷰어 화면 표시
    if (photos.length == 1) {
      // 1장이면 전체화면 뷰어
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TimelinePhotoFullscreenScreen(photo: photos[0]),
        ),
      );
    } else {
      // 2장 이상이면 스토리 뷰어
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TimelinePhotoStoryScreen(photos: photos, initialIndex: 0),
        ),
      );
    }
  }

  String _getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Map<String, dynamic>? _getTimelapseData(DateTime date) {
    final dateKey = _getDateKey(date);
    return _timelapseData[dateKey];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스토리 보관함'),
        backgroundColor: AppColors.secondary,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildScrollableCalendar(),
    );
  }

  Widget _buildCalendarDay(DateTime date, int day) {
    final timelapseData = _getTimelapseData(date);
    final dateKey = _getDateKey(date);
    // 실제 타임라인 데이터에 사진이 있는지 확인
    final hasActualPhotos =
        _timelineData.containsKey(dateKey) &&
        _timelineData[dateKey]!.isNotEmpty;
    final thumbnailUrl = timelapseData?['thumbnailUrl'] as String?;
    // 타임랩스에서 사진이 있다고 나왔고, 실제 사진 데이터도 있을 때만 썸네일 표시
    final shouldShowThumbnail =
        hasActualPhotos &&
        timelapseData?['hasPhoto'] == true &&
        thumbnailUrl != null;

    // 썸네일 URL이 있을 때만 사용
    final displayThumbnailUrl = shouldShowThumbnail ? thumbnailUrl : null;

    return GestureDetector(
      onTap: () {
        if (hasActualPhotos) {
          _loadPhotosForDate(date);
        }
      },
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (displayThumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  displayThumbnailUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: shouldShowThumbnail
                    ? Colors.black.withOpacity(0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: shouldShowThumbnail
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableCalendar() {
    if (_loadingUserInfo) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_joinDate == null) {
      return const Center(child: Text('캘린더를 불러올 수 없습니다.'));
    }

    final now = DateTime.now();
    final joinDate = _joinDate!;

    // 가입 월부터 현재 월까지의 총 월 수 계산
    final totalMonths =
        (now.year - joinDate.year) * 12 + (now.month - joinDate.month) + 1;

    return ListView.builder(
      controller: _scrollController,
      itemCount: totalMonths,
      itemBuilder: (context, index) {
        // 현재 월(index 0)부터 과거로
        final monthDate = DateTime(now.year, now.month - index);
        final year = monthDate.year;
        final month = monthDate.month;

        // 가입 월보다 이전이면 표시하지 않음
        if (monthDate.isBefore(DateTime(joinDate.year, joinDate.month))) {
          return const SizedBox.shrink();
        }

        final firstDay = DateTime(year, month, 1);
        final lastDay = DateTime(year, month + 1, 0);
        final daysInMonth = lastDay.day;
        final weekdayOfFirstDay = firstDay.weekday % 7;

        // 해당 월의 타임랩스 데이터 로드 여부 확인
        final monthKey = '$year-${month.toString().padLeft(2, '0')}';
        final needsLoad = !_timelapseData.keys.any(
          (key) => key.startsWith('$monthKey-'),
        );

        // 필요한 월의 데이터 로드 (lazy loading)
        if (needsLoad) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadTimelapseForMonth(year, month);
            }
          });
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$month월 $year',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              // 요일 헤더
              Row(
                children: ['일', '월', '화', '수', '목', '금', '토']
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              // 캘린더 그리드
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.0,
                ),
                itemCount: weekdayOfFirstDay + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < weekdayOfFirstDay) {
                    return const SizedBox.shrink();
                  }
                  final day = index - weekdayOfFirstDay + 1;
                  final date = DateTime(year, month, day);
                  return _buildCalendarDay(date, day);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
