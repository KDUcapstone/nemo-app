import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../app/constants.dart';

class StorageQuota {
  final String planType;
  final int maxPhotos;
  final int usedPhotos;
  final int remainPhotos;
  final double usagePercent;

  const StorageQuota({
    required this.planType,
    required this.maxPhotos,
    required this.usedPhotos,
    required this.remainPhotos,
    required this.usagePercent,
  });

  factory StorageQuota.fromJson(Map<String, dynamic> json) {
    return StorageQuota(
      planType: json['planType'] as String,
      maxPhotos: (json['maxPhotos'] as num).toInt(),
      usedPhotos: (json['usedPhotos'] as num).toInt(),
      remainPhotos: (json['remainPhotos'] as num).toInt(),
      usagePercent: (json['usagePercent'] as num).toDouble(),
    );
  }
}

class StorageApi {
  /// 저장 한도/사용량 조회
  /// API 명세서: GET /api/storage/quota
  /// 응답: { planType, maxPhotos, usedPhotos, remainPhotos, usagePercent }
  static Future<StorageQuota> fetchQuota() async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      // FREE 요금제 목업: 최대 20장, 사용 7장 (예시)
      const int max = 20;
      const int used = 7;
      const int remain = max - used;
      return const StorageQuota(
        planType: 'FREE',
        maxPhotos: max,
        usedPhotos: used,
        remainPhotos: remain,
        usagePercent: 35.0,
      );
    }

    print('💾 [StorageApi] fetchQuota 요청 시작');

    final http.Response res = await ApiClient.get(
      '/api/storage/quota',
    ).timeout(const Duration(seconds: 7));

    print('💾 [StorageApi] 응답 상태: ${res.statusCode}');
    print('💾 [StorageApi] 응답 본문: ${res.body}');

    if (res.statusCode == 200) {
      final Map<String, dynamic> map =
          jsonDecode(res.body) as Map<String, dynamic>;
      return StorageQuota.fromJson(map);
    }

    if (res.statusCode == 401) {
      // API 명세서: error: "UNAUTHORIZED", message: "유효하지 않은 인증 토큰입니다."
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      final errorCode = body['error'] as String?;
      final errorMessage = body['message'] as String?;

      print(
        '🔴 [StorageApi] 401 에러 상세: errorCode=$errorCode, errorMessage=$errorMessage, body=$body',
      );

      throw Exception(errorMessage ?? '유효하지 않은 인증 토큰입니다. 다시 로그인해주세요.');
    }

    if (res.statusCode == 404) {
      // API 명세서: error: "USER_NOT_FOUND", message: "해당 사용자를 찾을 수 없습니다."
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      final errorCode = body['error'] as String?;
      final errorMessage = body['message'] as String?;

      print(
        '🔴 [StorageApi] 404 에러 상세: errorCode=$errorCode, errorMessage=$errorMessage, body=$body',
      );

      throw Exception(errorMessage ?? '해당 사용자를 찾을 수 없습니다.');
    }

    print('🔴 [StorageApi] 예상치 못한 상태 코드: ${res.statusCode}');
    throw Exception('저장 한도 조회 실패 (${res.statusCode})');
  }
}
