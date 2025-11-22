import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/services/timeline_api.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/presentation/screens/share/timeline_photo_story_screen.dart';
import 'dart:io';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final TimelineApi _api = TimelineApi();
  final AuthService _authService = AuthService();
  Map<String, Map<String, dynamic>> _timelineDataByDate = {};
  Map<String, List<Map<String, dynamic>>> _timelapseDataByMonth = {};
  DateTime? _joinedDate; // 가입 월
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // 사용자 정보에서 가입일 가져오기
      DateTime? joinedDate;
      try {
        final userInfo = await _authService.getUserInfo();
        final createdAtStr = userInfo['createdAt'] as String?;
        if (createdAtStr != null && createdAtStr.isNotEmpty) {
          joinedDate = DateTime.parse(createdAtStr);
          // 가입일을 해당 월의 첫 날로 설정
          joinedDate = DateTime(joinedDate.year, joinedDate.month, 1);
        }
      } catch (e) {
        // 사용자 정보 로드 실패 시 현재 월로 설정
        final now = DateTime.now();
        joinedDate = DateTime(now.year, now.month, 1);
      }

      // 가입일이 없으면 현재 월로 설정
      if (joinedDate == null) {
        final now = DateTime.now();
        joinedDate = DateTime(now.year, now.month, 1);
      }

      // 전체 타임라인 로드
      final timelineData = await _api.getTimeline();
      final timelineMap = <String, Map<String, dynamic>>{};
      for (final entry in timelineData) {
        timelineMap[entry['date'] as String] = entry;
      }

      // 가입 월부터 현재 월까지 타임랩스 데이터 로드
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month, 1);
      final timelapseMap = <String, List<Map<String, dynamic>>>{};

      // 가입 월부터 현재 월까지 모든 월 생성
      DateTime month = DateTime(joinedDate.year, joinedDate.month, 1);
      while (month.isBefore(currentMonth) ||
          month.isAtSameMomentAs(currentMonth)) {
        final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
        try {
          final data = await _api.getTimelapse(
            year: month.year,
            month: month.month,
          );
          timelapseMap[key] = data;
        } catch (e) {
          // 특정 월 로드 실패해도 계속 진행
        }
        // 다음 달로 이동
        if (month.month == 12) {
          month = DateTime(month.year + 1, 1, 1);
        } else {
          month = DateTime(month.year, month.month + 1, 1);
        }
      }

      setState(() {
        _timelineDataByDate = timelineMap;
        _timelapseDataByMonth = timelapseMap;
        _joinedDate = joinedDate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMonth(int year, int month) async {
    final key = '$year-${month.toString().padLeft(2, '0')}';
    if (_timelapseDataByMonth.containsKey(key)) return; // 이미 로드됨

    try {
      final data = await _api.getTimelapse(year: year, month: month);
      setState(() {
        _timelapseDataByMonth[key] = data;
      });
    } catch (e) {
      // 로드 실패해도 무시
    }
  }

  void _showPhotoStory(String date) async {
    // 해당 날짜의 타임라인 데이터에서 사진 목록 가져오기
    final entry = _timelineDataByDate[date];
    if (entry == null) {
      // 타임라인 데이터가 없으면 API로 다시 로드
      try {
        final dateObj = DateTime.parse(date);
        final timelineData = await _api.getTimeline(
          year: dateObj.year,
          month: dateObj.month,
        );
        final found = timelineData.firstWhere(
          (e) => e['date'] == date,
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty) {
          final photos = (found['photos'] as List).cast<Map<String, dynamic>>();
          if (photos.isNotEmpty && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TimelinePhotoStoryScreen(photos: photos, initialIndex: 0),
              ),
            );
          }
        }
      } catch (e) {
        // 에러 무시
      }
      return;
    }

    final photos = (entry['photos'] as List).cast<Map<String, dynamic>>();
    if (photos.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TimelinePhotoStoryScreen(photos: photos, initialIndex: 0),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스토리 보관함'),
        backgroundColor: AppColors.secondary,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '타임라인을 불러올 수 없습니다.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loadInitialData,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              )
            : _joinedDate != null
            ? _CalendarTimelineView(
                joinedDate: _joinedDate!,
                timelineDataByDate: _timelineDataByDate,
                timelapseDataByMonth: _timelapseDataByMonth,
                onDateTap: _showPhotoStory,
                onMonthVisible: _loadMonth,
              )
            : const Center(child: Text('캘린더를 불러올 수 없습니다.')),
      ),
    );
  }
}

class _CalendarTimelineView extends StatelessWidget {
  final DateTime joinedDate; // 가입 월
  final Map<String, Map<String, dynamic>> timelineDataByDate;
  final Map<String, List<Map<String, dynamic>>> timelapseDataByMonth;
  final void Function(String date) onDateTap;
  final void Function(int year, int month) onMonthVisible;

  const _CalendarTimelineView({
    required this.joinedDate,
    required this.timelineDataByDate,
    required this.timelapseDataByMonth,
    required this.onDateTap,
    required this.onMonthVisible,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final joinedMonth = DateTime(joinedDate.year, joinedDate.month, 1);

    // 가입 월부터 현재 월까지 모든 월 생성
    final months = <DateTime>[];
    DateTime month = joinedMonth;
    while (month.isBefore(currentMonth) ||
        month.isAtSameMomentAs(currentMonth)) {
      months.add(month);
      // 다음 달로 이동
      if (month.month == 12) {
        month = DateTime(month.year + 1, 1, 1);
      } else {
        month = DateTime(month.year, month.month + 1, 1);
      }
    }

    // 최신순으로 정렬 (현재 월이 먼저)
    months.sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: months.length,
      itemBuilder: (context, index) {
        final month = months[index];
        return _MonthCalendarWidget(
          year: month.year,
          month: month.month,
          timelineDataByDate: timelineDataByDate,
          timelapseData:
              timelapseDataByMonth['${month.year}-${month.month.toString().padLeft(2, '0')}'],
          onDateTap: onDateTap,
          onVisible: () => onMonthVisible(month.year, month.month),
        );
      },
    );
  }
}

class _MonthCalendarWidget extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, Map<String, dynamic>> timelineDataByDate;
  final List<Map<String, dynamic>>? timelapseData;
  final void Function(String date) onDateTap;
  final VoidCallback onVisible;

  const _MonthCalendarWidget({
    required this.year,
    required this.month,
    required this.timelineDataByDate,
    this.timelapseData,
    required this.onDateTap,
    required this.onVisible,
  });

  @override
  Widget build(BuildContext context) {
    // 첫 렌더링 시 해당 월 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) => onVisible());

    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final firstWeekday = firstDay.weekday % 7; // 일요일 = 0
    final daysInMonth = lastDay.day;

    // 날짜별 썸네일 맵 생성
    final dateThumbnailMap = <int, String?>{};
    final datePhotoCountMap = <int, int>{};
    if (timelapseData != null) {
      for (final entry in timelapseData!) {
        final dateStr = entry['date'] as String;
        final dateObj = DateTime.parse(dateStr);
        if (dateObj.year == year && dateObj.month == month) {
          dateThumbnailMap[dateObj.day] = entry['thumbnailUrl'] as String?;
          datePhotoCountMap[dateObj.day] = entry['photoCount'] as int? ?? 0;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            '$month월 $year',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // 요일 헤더
              Row(
                children: ['일', '월', '화', '수', '목', '금', '토']
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              // 달력 그리드
              ...List.generate(
                (daysInMonth + firstWeekday + 6) ~/ 7,
                (weekIndex) => Row(
                  children: List.generate(7, (dayIndex) {
                    final cellIndex = weekIndex * 7 + dayIndex;
                    final day = cellIndex - firstWeekday + 1;

                    if (day < 1 || day > daysInMonth) {
                      return Expanded(child: Container());
                    }

                    final thumbnailUrl = dateThumbnailMap[day];
                    final photoCount = datePhotoCountMap[day] ?? 0;
                    final hasPhoto = photoCount > 0;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: GestureDetector(
                          onTap: hasPhoto
                              ? () {
                                  final dateStr =
                                      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                                  onDateTap(dateStr);
                                }
                              : null,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (hasPhoto && thumbnailUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildThumbnail(thumbnailUrl),
                                    ),
                                  // 날짜 숫자
                                  Positioned(
                                    bottom: 4,
                                    left: 4,
                                    right: 4,
                                    child: Text(
                                      '$day',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: hasPhoto
                                            ? Colors.white
                                            : Colors.black87,
                                        shadows: hasPhoto
                                            ? [
                                                Shadow(
                                                  color: Colors.black54,
                                                  blurRadius: 2,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildThumbnail(String thumbnailUrl) {
    final isFile = thumbnailUrl.isNotEmpty && !thumbnailUrl.startsWith('http');
    return isFile
        ? Image.file(
            File(thumbnailUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
          )
        : Image.network(
            thumbnailUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
          );
  }
}
