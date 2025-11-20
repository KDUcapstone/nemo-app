import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/app/constants.dart';
import 'auth_service.dart';

class TimelineApi {
  static Uri _u(String p) => Uri.parse('${AuthService.baseUrl}$p');

  /// 타임라인 조회 (날짜별 사진 목록)
  /// year, month는 선택적 파라미터
  Future<List<Map<String, dynamic>>> getTimeline({
    int? year,
    int? month,
  }) async {
    if (AppConstants.useMockApi) {
      // 모킹 데이터 반환
      await Future.delayed(const Duration(milliseconds: 300));

      final now = DateTime.now();
      final result = <Map<String, dynamic>>[];

      // year, month 파라미터에 따라 데이터 필터링
      // 파라미터가 없으면 전체 타임라인 반환
      final targetYear = year ?? now.year;
      final targetMonth = month ?? now.month;

      // 현재 월 기준으로 최근 몇 개월의 목업 데이터 생성
      for (int monthOffset = 0; monthOffset < 3; monthOffset++) {
        final date = DateTime(now.year, now.month - monthOffset);
        final checkYear = date.year;
        final checkMonth = date.month;

        // 요청된 year, month와 일치하는 경우만 추가
        if (year != null && month != null) {
          if (checkYear != targetYear || checkMonth != targetMonth) {
            continue;
          }
        }

        // 각 월마다 몇 개의 날짜에 사진 추가
        final daysWithPhotos = monthOffset == 0
            ? [now.day - 2, now.day - 5, now.day - 8, now.day - 10] // 현재 월
            : monthOffset == 1
            ? [15, 18, 22, 25] // 지난 달
            : [5, 10, 15, 20, 28]; // 2개월 전

        for (final day in daysWithPhotos) {
          if (day < 1 || day > DateTime(checkYear, checkMonth + 1, 0).day) {
            continue;
          }

          final dateStr =
              '$checkYear-${checkMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          // 일부 날짜는 2장 이상의 사진을 가지도록 설정
          int photoCount;
          if (day % 4 == 0) {
            // 4의 배수일 때는 4장
            photoCount = 4;
          } else if (day % 3 == 0) {
            // 3의 배수일 때는 3장
            photoCount = 3;
          } else if (day % 2 == 0) {
            // 2의 배수일 때는 2장
            photoCount = 2;
          } else {
            // 나머지는 1장
            photoCount = 1;
          }

          final photos = <Map<String, dynamic>>[];
          for (int i = 0; i < photoCount; i++) {
            photos.add({
              'photoId':
                  1000 +
                  (checkYear * 10000) +
                  (checkMonth * 100) +
                  (day * 10) +
                  i,
              'imageUrl':
                  'https://picsum.photos/seed/timeline$checkYear$checkMonth$day$i/600/800',
              'location': ['홍대 포토그레이', '신촌 포토시그널', '건대 하루필름', '강남 포토이즘'][i % 4],
              'brand': ['인생네컷', '포토시그널', '하루필름', '포토이즘'][i % 4],
            });
          }

          result.add({'date': dateStr, 'photos': photos});
        }
      }

      // 날짜 역순 정렬 (최신순)
      result.sort(
        (a, b) => b['date'].toString().compareTo(a['date'].toString()),
      );

      return result;
    }

    final qp = <String, String>{};
    if (year != null) qp['year'] = year.toString();
    if (month != null) qp['month'] = month.toString();

    final uri = _u(
      '/api/timeline',
    ).replace(queryParameters: qp.isEmpty ? null : qp);
    final r = await http.get(uri, headers: _h());

    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      if (body is List) {
        return body.cast<Map<String, dynamic>>();
      }
      throw Exception('응답 형식 오류: 배열이 아님');
    }
    if (r.statusCode == 401) {
      throw Exception('인증이 필요합니다. (401)');
    }
    throw Exception('타임라인 조회 실패 (${r.statusCode})');
  }

  /// 캘린더 타임랩스 조회 (특정 월의 날짜별 사진 유무 및 썸네일)
  /// year, month는 필수 파라미터
  Future<List<Map<String, dynamic>>> getTimelapse({
    required int year,
    required int month,
  }) async {
    if (AppConstants.useMockApi) {
      // 모킹 데이터: 해당 월의 일부 날짜에 사진이 있다고 가정
      await Future.delayed(const Duration(milliseconds: 300));
      final now = DateTime.now();
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final result = <Map<String, dynamic>>[];

      // 현재 월인지 확인하여 다른 패턴 적용
      final isCurrentMonth = year == now.year && month == now.month;

      for (int day = 1; day <= daysInMonth; day++) {
        bool hasPhoto;

        if (isCurrentMonth) {
          // 현재 월: 과거 날짜들에만 사진 (미래는 제외)
          hasPhoto =
              day <= now.day &&
              (day % 4 == 0 || day % 7 == 0 || day == now.day - 2);
        } else {
          // 과거 월: 일부 날짜에 사진
          hasPhoto =
              day % 3 == 0 ||
              day % 5 == 0 ||
              day == 15 ||
              day == 18 ||
              day == 22;
        }

        // getTimeline과 동일한 로직으로 사진 수 계산
        int photoCount = 0;
        if (hasPhoto) {
          if (day % 4 == 0) {
            // 4의 배수일 때는 4장
            photoCount = 4;
          } else if (day % 3 == 0) {
            // 3의 배수일 때는 3장
            photoCount = 3;
          } else if (day % 2 == 0) {
            // 2의 배수일 때는 2장
            photoCount = 2;
          } else {
            // 나머지는 1장
            photoCount = 1;
          }
        }

        result.add({
          'date':
              '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
          'hasPhoto': hasPhoto,
          'thumbnailUrl': hasPhoto
              ? 'https://picsum.photos/seed/timelapse$year$month$day/200/200'
              : null,
          'photoCount': photoCount,
        });
      }
      return result;
    }

    final uri = _u('/api/timeline/timelapse').replace(
      queryParameters: {'year': year.toString(), 'month': month.toString()},
    );
    final r = await http.get(uri, headers: _h());

    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      if (body is List) {
        return body.cast<Map<String, dynamic>>();
      }
      throw Exception('응답 형식 오류: 배열이 아님');
    }
    if (r.statusCode == 400) {
      final body = r.body.isNotEmpty ? jsonDecode(r.body) : {};
      throw Exception(body['message'] ?? 'year와 month 파라미터는 필수입니다.');
    }
    if (r.statusCode == 401) {
      throw Exception('인증이 필요합니다. (401)');
    }
    throw Exception('타임랩스 조회 실패 (${r.statusCode})');
  }

  Map<String, String> _h({bool json = false}) {
    final h = <String, String>{
      'Authorization': 'Bearer ${AuthService.accessToken ?? ''}',
    };
    if (json) h['Content-Type'] = 'application/json';
    return h;
  }
}
