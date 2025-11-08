import 'dart:convert';
import 'package:frontend/app/constants.dart';
import 'package:frontend/services/api_client.dart';

class MapApi {
  static Future<Map<String, dynamic>> getMapInit() async {
    if (AppConstants.useMockApi) {
      await Future<void>.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'map': {
          'defaultLat': 37.5665,
          'defaultLng': 126.9780,
          'defaultZoom': 15,
          'minZoom': 12,
          'maxZoom': 18,
          'debounceMs': 300,
          'minMoveMetersForRefresh': 150,
          'maxMarkers': 80,
          'cluster': true,
        },
        'search': {
          'keywords': ['포토부스', '인생네컷', '하루필름', '포토이즘', '포토시그널', '포토그레이'],
          'brandFilterEnabled': true,
        },
        'uiHints': {
          'locationPermissionGuide': '위치 권한을 허용하면 내 주변 포토부스를 자동으로 보여줘요.',
          'dataNotice': '장소 정보는 Naver Maps 기반입니다.',
        },
        'featureFlags': {'useNaverPlaces': true, 'useDelta': true},
        'serverTs': DateTime.now().toUtc().toIso8601String(),
        'minAppVersion': '1.0.0',
      };
    }
    final res = await ApiClient.get('/api/map/init');
    if (res.statusCode != 200) {
      throw Exception('map init 실패: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getViewport({
    required double neLat,
    required double neLng,
    required double swLat,
    required double swLng,
    int? zoom,
    String? brand,
    int? limit,
    bool? cluster,
  }) async {
    if (AppConstants.useMockApi) {
      await Future<void>.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );

      // 현재 뷰포트 중심 계산
      final centerLat = (neLat + swLat) / 2;
      final centerLng = (neLng + swLng) / 2;

      return {
        'items': [
          {
            'placeId': 'pb_mock_1',
            'name': '인생네컷 테스트점',
            'brand': '인생네컷',
            'latitude': centerLat + 0.001,
            'longitude': centerLng + 0.001,
            'roadAddress': '현재 위치 근처',
            'naverPlaceUrl': 'https://map.naver.com/...',
            'distanceMeter': 120,
            'cluster': false,
          },
          {
            'placeId': 'pb_mock_2',
            'name': '포토그레이 테스트점',
            'brand': '포토그레이',
            'latitude': centerLat - 0.002,
            'longitude': centerLng + 0.002,
            'roadAddress': '현재 위치 근처',
            'naverPlaceUrl': 'https://map.naver.com/...',
            'distanceMeter': 250,
            'cluster': false,
          },
          {
            'placeId': 'pb_mock_3',
            'name': '하루필름 테스트점',
            'brand': '하루필름',
            'latitude': centerLat + 0.002,
            'longitude': centerLng - 0.001,
            'roadAddress': '현재 위치 근처',
            'naverPlaceUrl': 'https://map.naver.com/...',
            'distanceMeter': 180,
            'cluster': false,
          },
          {
            'placeId': 'pb_cluster_1',
            'cluster': true,
            'count': 8,
            'latitude': centerLat - 0.003,
            'longitude': centerLng - 0.003,
            'bucketSize': 100,
          },
        ],
        'viewport': {
          'neLat': neLat,
          'neLng': neLng,
          'swLat': swLat,
          'swLng': swLng,
          'zoom': zoom ?? 14,
        },
        'serverTs': DateTime.now().toUtc().toIso8601String(),
      };
    }
    final query = <String, String>{
      'neLat': neLat.toString(),
      'neLng': neLng.toString(),
      'swLat': swLat.toString(),
      'swLng': swLng.toString(),
      if (zoom != null) 'zoom': zoom.toString(),
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      if (limit != null) 'limit': limit.toString(),
      if (cluster != null) 'cluster': cluster.toString(),
    };
    final res = await ApiClient.get(
      '/api/map/photobooths/viewport',
      queryParameters: query,
    );
    if (res.statusCode != 200) {
      throw Exception('viewport 실패: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getDelta({
    required double neLat,
    required double neLng,
    required double swLat,
    required double swLng,
    required String sinceTs,
    required List<String> knownIds,
    String? brand,
    bool? cluster,
  }) async {
    if (AppConstants.useMockApi) {
      await Future<void>.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'added': [
          {
            'placeId': 'pb_new_1',
            'name': '인생네컷 북촌점',
            'brand': '인생네컷',
            'latitude': 37.58000,
            'longitude': 126.98000,
            'roadAddress': '서울 종로구 ...',
            'distanceMeter': 430,
          },
          {
            'placeId': 'pb_cluster_2',
            'cluster': true,
            'count': 9,
            'latitude': 37.56810,
            'longitude': 126.97790,
            'bucketSize': 100,
          },
        ],
        'updated': [
          {
            'placeId': 'pb_mock_1',
            'name': '인생네컷 광화문점',
            'brand': '인생네컷',
            'latitude': 37.57021,
            'longitude': 126.97689,
          },
        ],
        'removedIds': ['pb_removed_1'],
        'serverTs': DateTime.now().toUtc().toIso8601String(),
      };
    }
    final body = {
      'neLat': neLat,
      'neLng': neLng,
      'swLat': swLat,
      'swLng': swLng,
      'sinceTs': sinceTs,
      'knownIds': knownIds,
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      if (cluster != null) 'cluster': cluster,
    };
    final res = await ApiClient.post(
      '/api/map/photobooths/viewport/delta',
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception('delta 실패: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
