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
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    if (res.statusCode == 401) {
      final body = res.body.isNotEmpty ? jsonDecode(utf8.decode(res.bodyBytes)) : {};
      throw Exception(body['message'] ?? '유효한 액세스 토큰이 필요합니다.');
    }
    throw Exception('map init 실패: ${res.statusCode}');
  }

  // GET /api/map/photos - 지도용 사진 위치 데이터 조회
  // API 명세서: 위치 정보가 있는 사진들을 반환하여 지도 위에 표시
  static Future<List<Map<String, dynamic>>> getMapPhotos() async {
    if (AppConstants.useMockApi) {
      await Future<void>.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return [
        {
          'photoId': 101,
          'latitude': 37.5567,
          'longitude': 126.9234,
          'imageUrl': 'https://picsum.photos/seed/photo101/800/1066',
          'takenAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'brand': '인생네컷',
          'location': '홍대 포토그레이',
        },
        {
          'photoId': 104,
          'latitude': 37.5389,
          'longitude': 127.0732,
          'imageUrl': 'https://picsum.photos/seed/photo104/800/1066',
          'takenAt': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(),
          'brand': '포토시그널',
          'location': '건대입구역 포토시그널',
        },
      ];
    }
    final res = await ApiClient.get('/api/map/photos');
    if (res.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return const <Map<String, dynamic>>[];
    }
    if (res.statusCode == 401) {
      final body = res.body.isNotEmpty ? jsonDecode(utf8.decode(res.bodyBytes)) : {};
      throw Exception(body['message'] ?? '로그인이 필요합니다.');
    }
    throw Exception('지도용 사진 위치 조회 실패 (${res.statusCode})');
  }

  // GET /api/map/photos/detail - 특정 위치 상세 사진 조회
  // API 명세서: location 또는 latitude+longitude 기반 필터링
  static Future<Map<String, dynamic>> getMapPhotosDetail({
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    if (AppConstants.useMockApi) {
      await Future<void>.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (location == null && (latitude == null || longitude == null)) {
        throw Exception('장소 이름 또는 좌표 정보가 필요합니다.');
      }
      return {
        'location': location ?? '테스트 위치',
        'photos': [
          {
            'photoId': 101,
            'imageUrl': 'https://picsum.photos/seed/photo101/800/1066',
            'takenAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            'brand': '인생네컷',
          },
          {
            'photoId': 102,
            'imageUrl': 'https://picsum.photos/seed/photo102/800/1066',
            'takenAt': DateTime.now().subtract(const Duration(days: 1, hours: 1)).toIso8601String(),
            'brand': '인생네컷',
          },
        ],
      };
    }
    final query = <String, String>{};
    if (location != null && location.isNotEmpty) {
      query['location'] = location;
    }
    if (latitude != null && longitude != null) {
      query['latitude'] = latitude.toString();
      query['longitude'] = longitude.toString();
    }
    
    if (query.isEmpty) {
      throw Exception('장소 이름 또는 좌표 정보가 필요합니다.');
    }
    
    final res = await ApiClient.get(
      '/api/map/photos/detail',
      queryParameters: query,
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    if (res.statusCode == 400) {
      final body = res.body.isNotEmpty ? jsonDecode(utf8.decode(res.bodyBytes)) : {};
      final error = body['error'] as String?;
      if (error == 'LOCATION_REQUIRED') {
        throw Exception(body['message'] ?? '장소 이름 또는 좌표 정보가 필요합니다.');
      }
      throw Exception(body['message'] ?? '잘못된 요청입니다.');
    }
    if (res.statusCode == 401) {
      throw Exception('로그인이 필요합니다.');
    }
    throw Exception('특정 위치 상세 사진 조회 실패 (${res.statusCode})');
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
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    if (res.statusCode == 400) {
      final body = res.body.isNotEmpty ? jsonDecode(utf8.decode(res.bodyBytes)) : {};
      final error = body['error'] as String?;
      if (error == 'INVALID_VIEWPORT') {
        throw Exception(body['message'] ?? '유효한 뷰포트(neLat/neLng/swLat/swLng)가 필요합니다.');
      }
      throw Exception(body['message'] ?? '잘못된 요청입니다.');
    }
    if (res.statusCode == 401) {
      final body = res.body.isNotEmpty ? jsonDecode(utf8.decode(res.bodyBytes)) : {};
      throw Exception(body['message'] ?? '유효한 액세스 토큰이 필요합니다.');
    }
    if (res.statusCode == 429) {
      final body = res.body.isNotEmpty ? jsonDecode(utf8.decode(res.bodyBytes)) : {};
      final error = body['error'] as String?;
      if (error == 'RATE_LIMIT') {
        throw Exception(body['message'] ?? '잠시 후 다시 시도해주세요.');
      }
      throw Exception(body['message'] ?? '요청이 너무 많습니다.');
    }
    if (res.statusCode == 502) {
      final body = res.body.isNotEmpty ? jsonDecode(utf8.decode(res.bodyBytes)) : {};
      final error = body['error'] as String?;
      if (error == 'UPSTREAM_FAILURE') {
        throw Exception(body['message'] ?? '장소 데이터를 불러오지 못했습니다.');
      }
      throw Exception(body['message'] ?? '서버 오류');
    }
    throw Exception('viewport 실패: ${res.statusCode}');
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
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    if (res.statusCode == 400) {
      final body = res.body.isNotEmpty ? jsonDecode(utf8.decode(res.bodyBytes)) : {};
      final error = body['error'] as String?;
      if (error == 'INVALID_VIEWPORT') {
        throw Exception(body['message'] ?? '유효한 뷰포트(neLat/neLng/swLat/swLng)가 필요합니다.');
      }
      throw Exception(body['message'] ?? '잘못된 요청입니다.');
    }
    if (res.statusCode == 401) {
      final body = res.body.isNotEmpty ? jsonDecode(utf8.decode(res.bodyBytes)) : {};
      throw Exception(body['message'] ?? '유효한 액세스 토큰이 필요합니다.');
    }
    throw Exception('delta 실패: ${res.statusCode}');
  }
}
