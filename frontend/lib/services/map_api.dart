import 'dart:convert';
import 'package:http/http.dart' as http;
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

    // 🔍 로그: map init 호출
    print('🗺️ [MapApi] GET /api/map/init');

    final res = await ApiClient.get('/api/map/init');

    print('🗺️ [MapApi] /api/map/init status=${res.statusCode}');

    if (res.statusCode != 200) {
      throw Exception('map init 실패: ${res.statusCode}');
    }
    if (res.statusCode == 401) {
      final body = res.body.isNotEmpty
          ? jsonDecode(utf8.decode(res.bodyBytes))
          : {};
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
          'takenAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'brand': '인생네컷',
          'location': '홍대 포토그레이',
        },
        {
          'photoId': 104,
          'latitude': 37.5389,
          'longitude': 127.0732,
          'imageUrl': 'https://picsum.photos/seed/photo104/800/1066',
          'takenAt': DateTime.now()
              .subtract(const Duration(days: 6))
              .toIso8601String(),
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
      final body = res.body.isNotEmpty
          ? jsonDecode(utf8.decode(res.bodyBytes))
          : {};
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
            'takenAt': DateTime.now()
                .subtract(const Duration(days: 1))
                .toIso8601String(),
            'brand': '인생네컷',
          },
          {
            'photoId': 102,
            'imageUrl': 'https://picsum.photos/seed/photo102/800/1066',
            'takenAt': DateTime.now()
                .subtract(const Duration(days: 1, hours: 1))
                .toIso8601String(),
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
      final body = res.body.isNotEmpty
          ? jsonDecode(utf8.decode(res.bodyBytes))
          : {};
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

      // 🔍 로그: mock 모드에서의 뷰포트 정보
      print(
        '🧭 [MapApi-mock] viewport ne=($neLat, $neLng), '
        'sw=($swLat, $swLng), center=($centerLat, $centerLng), zoom=$zoom',
      );

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

    // 🔍 로그: 실제 서버로 보내는 뷰포트/쿼리 정보
    final centerLat = (neLat + swLat) / 2;
    final centerLng = (neLng + swLng) / 2;
    print(
      '🧭 [MapApi] viewport ne=($neLat, $neLng), '
      'sw=($swLat, $swLng), center=($centerLat, $centerLng), '
      'zoom=$zoom, brand=$brand, limit=$limit, cluster=$cluster',
    );
    print('🌐 [MapApi] GET /api/map/photobooths/viewport query=$query');

    final res = await ApiClient.get(
      '/api/map/photobooths/viewport',
      queryParameters: query,
    );

    print('📡 [MapApi] /api/map/photobooths/viewport status=${res.statusCode}');

    if (res.statusCode != 200) {
      // 에러 바디도 같이 보이게
      final bodyText = utf8.decode(res.bodyBytes);
      print('⚠️ [MapApi] viewport 실패 body=$bodyText');
      throw Exception('viewport 실패: ${res.statusCode}');
    }

    final decoded =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    // 🔍 로그: 응답 items 개수
    final items = decoded['items'] as List<dynamic>? ?? const [];
    print('📍 [MapApi] viewport 응답 items=${items.length}개');

    return decoded;
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

      print(
        '🧭 [MapApi-mock] delta sinceTs=$sinceTs, knownIds=${knownIds.length}개',
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

    // 🔍 로그: delta 요청 바디
    print(
      '🔁 [MapApi] POST /api/map/photobooths/viewport/delta '
      'body={ne=($neLat,$neLng), sw=($swLat,$swLng), sinceTs=$sinceTs, '
      'knownIds=${knownIds.length}, brand=$brand, cluster=$cluster}',
    );

    final res = await ApiClient.post(
      '/api/map/photobooths/viewport/delta',
      body: body,
    );

    print(
      '📡 [MapApi] /api/map/photobooths/viewport/delta status=${res.statusCode}',
    );

    if (res.statusCode != 200) {
      final bodyText = utf8.decode(res.bodyBytes);
      print('⚠️ [MapApi] delta 실패 body=$bodyText');
      throw Exception('delta 실패: ${res.statusCode}');
    }

    final decoded =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    // 🔍 로그: delta 응답 요약
    final added = decoded['added'] as List<dynamic>? ?? const [];
    final updated = decoded['updated'] as List<dynamic>? ?? const [];
    final removedIds = decoded['removedIds'] as List<dynamic>? ?? const [];
    print(
      '📍 [MapApi] delta 응답: added=${added.length}, '
      'updated=${updated.length}, removed=${removedIds.length}',
    );

    return decoded;
  }

  // GET /api/map/photobooths/search - 포토부스 자동완성 검색
  static Future<List<Map<String, dynamic>>> searchPhotobooths({
    required String keyword,
    double? lat,
    double? lng,
    int? limit,
  }) async {
    if (AppConstants.useMockApi) {
      await Future<void>.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return [
        {
          'placeId': 'n123abc',
          'name': '인생네컷 수유점',
          'brand': '인생네컷',
          'latitude': 37.63812,
          'longitude': 127.02631,
          'roadAddress': '서울 강북구 도봉로 10길 12',
          'distanceMeter': lat != null && lng != null ? 120 : null,
        },
        {
          'placeId': 'n456def',
          'name': '포토그레이 명동점',
          'brand': '포토그레이',
          'latitude': 37.56312,
          'longitude': 126.98231,
          'roadAddress': '서울 중구 명동길 22',
          'distanceMeter': lat != null && lng != null ? 430 : null,
        },
      ];
    }

    // QueryString을 올바르게 구성
    final queryParams = <String, String>{
      'keyword': keyword,
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
      if (limit != null) 'limit': limit.toString(),
    };

    print('🔍 [MapApi] GET /api/map/photobooths/search query=$queryParams');

    // Uri를 직접 구성하여 QueryString 추가
    final url = ApiClient.uri('/api/map/photobooths/search', queryParams);
    
    final res = await http.get(
      url,
      headers: ApiClient.headers(includeAuth: false), // 검색은 공개 API
    );

    print('📡 [MapApi] /api/map/photobooths/search status=${res.statusCode}');

    if (res.statusCode != 200) {
      final bodyText = utf8.decode(res.bodyBytes);
      print('⚠️ [MapApi] search 실패 body=$bodyText');
      if (res.statusCode == 400) {
        final body = jsonDecode(bodyText) as Map<String, dynamic>?;
        throw Exception(body?['message'] ?? '잘못된 요청입니다.');
      }
      throw Exception('검색 실패: ${res.statusCode}');
    }

    // 응답 본문 확인을 위한 디버깅 로그 추가
    final bodyText = utf8.decode(res.bodyBytes);
    print('📦 [MapApi] search 응답 본문: $bodyText');
    print('📦 [MapApi] search 응답 본문 길이: ${bodyText.length}');

    final decoded = jsonDecode(bodyText);
    print('📦 [MapApi] search 파싱된 타입: ${decoded.runtimeType}');

    if (decoded is List) {
      final results = decoded.cast<Map<String, dynamic>>();
      print('📍 [MapApi] search 응답 ${results.length}개 결과');
      if (results.isNotEmpty) {
        print('📍 [MapApi] 첫 번째 결과: ${results.first}');
      }
      return results;
    }

    print('⚠️ [MapApi] search 응답이 List가 아님: $decoded');
    return const <Map<String, dynamic>>[];
  }
}
