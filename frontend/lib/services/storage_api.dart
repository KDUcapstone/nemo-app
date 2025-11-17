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
  static Future<StorageQuota> fetchQuota() async {
    if (AppConstants.useMockApi) {
      await Future.delayed(Duration(milliseconds: AppConstants.simulatedNetworkDelayMs));
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

    final http.Response res = await ApiClient
        .get('/api/storage/quota')
        .timeout(const Duration(seconds: 7));
    if (res.statusCode == 200) {
      final Map<String, dynamic> map = jsonDecode(res.body) as Map<String, dynamic>;
      return StorageQuota.fromJson(map);
    }
    if (res.statusCode == 401) {
      throw Exception('UNAUTHORIZED');
    }
    if (res.statusCode == 404) {
      throw Exception('USER_NOT_FOUND');
    }
    throw Exception('FAILED_${res.statusCode}');
  }
}


