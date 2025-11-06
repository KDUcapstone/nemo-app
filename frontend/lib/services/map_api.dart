import 'dart:convert';
import 'package:frontend/app/constants.dart';
import 'package:frontend/services/api_client.dart';

class MapApi {
  static Future<Map<String, dynamic>> getHomeConfig() async {
    if (AppConstants.useMockApi) {
      await Future<void>.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'defaults': {
          'zoom': 14,
          'cluster': true,
          'pollingSec': 15,
          'idlePollingSec': 45,
          'minCameraMoveMeters': 80,
        },
        'brands': ['인생네컷', '포토이즘', '하루필름', '포토시그널'],
        'messages': {
          'permissionGuide': '위치 권한을 허용하면 내 주변 포토부스를 볼 수 있어요.',
          'emptyResult': '이 근처엔 결과가 적어요. 지도를 움직여 다른 곳을 탐색해보세요!',
        },
      };
    }
    final res = await ApiClient.get('/api/map/home-config');
    if (res.statusCode != 200) {
      throw Exception('home-config 실패: ${res.statusCode}');
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
      return {
        'items': [
          {
            'placeId': 'pb_mock_1',
            'name': '인생네컷 광화문점',
            'brand': '인생네컷',
            'latitude': 37.57021,
            'longitude': 126.97689,
            'address': '서울 종로구 ...',
            'openNow': true,
            'rating': 4.5,
            'userRatingsTotal': 128,
            'naverPlaceUrl': 'https://map.naver.com/...',
          },
          {
            'placeId': 'pb_cluster_1',
            'cluster': true,
            'count': 12,
            'latitude': 37.5668,
            'longitude': 126.9783,
            'bucketSize': 120,
          }
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
    required String since,
    int? zoom,
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
            'name': '포토이즘 시청점 2호',
            'brand': '포토이즘',
            'latitude': 37.56591,
            'longitude': 126.97702,
          }
        ],
        'updated': [
          {
            'placeId': 'pb_mock_1',
            'openNow': false,
            'rating': 4.4,
          }
        ],
        'removed': [
          {'placeId': 'pb_removed_1'}
        ],
        'serverTs': DateTime.now().toUtc().toIso8601String(),
      };
    }
    final query = <String, String>{
      'neLat': neLat.toString(),
      'neLng': neLng.toString(),
      'swLat': swLat.toString(),
      'swLng': swLng.toString(),
      'since': since,
      if (zoom != null) 'zoom': zoom.toString(),
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      if (cluster != null) 'cluster': cluster.toString(),
    };
    final res = await ApiClient.get(
      '/api/map/photobooths/viewport/delta',
      queryParameters: query,
    );
    if (res.statusCode != 200) {
      throw Exception('delta 실패: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}


