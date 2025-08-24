import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:frontend/app/constants.dart';
import 'package:frontend/services/auth_service.dart';

class AlbumApi {
  static Uri _uri(String path) => Uri.parse('${AuthService.baseUrl}$path');

  static Map<String, String> _headersJson() {
    final token = AuthService.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET /api/albums?sort=&page=&size=&favoriteOnly=
  static Future<Map<String, dynamic>> getAlbums({
    String sort = 'createdAt,desc',
    int page = 0,
    int size = 10,
    bool? favoriteOnly,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      // mock content: 6개 고정 더미에서 페이징
      final mock = List.generate(6, (i) {
        final id = 20 - i;
        return {
          'albumId': id,
          'title': i == 0 ? '2025 여름방학' : '더미 앨범 $id',
          'coverPhotoUrl': i % 2 == 0
              ? 'https://picsum.photos/seed/album$id/600/800'
              : null,
          'photoCount': (i + 1) * 2,
          'createdAt': DateTime(
            2025,
            7,
            21,
            15,
            10,
            0,
          ).subtract(Duration(days: i * 5)).toIso8601String(),
        };
      });
      final start = page * size;
      final end = (start + size).clamp(0, mock.length);
      final content = start < mock.length
          ? mock.sublist(start, end)
          : <Map<String, dynamic>>[];
      return {
        'content': content,
        'page': {
          'size': size,
          'totalElements': mock.length,
          'totalPages': (mock.length / size).ceil(),
          'number': page,
        },
      };
    }

    final q = <String, String>{
      'sort': sort,
      'page': '$page',
      'size': '$size',
      if (favoriteOnly != null) 'favoriteOnly': favoriteOnly.toString(),
    };
    final uri = _uri('/api/albums').replace(queryParameters: q);
    final res = await http.get(uri, headers: _headersJson());
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch albums (${res.statusCode})');
  }

  // POST /api/albums
  static Future<Map<String, dynamic>> createAlbum({
    required String title,
    String? description,
    int? coverPhotoId,
    List<int>? photoIdList,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      final id = DateTime.now().millisecondsSinceEpoch % 100000;
      final count = photoIdList?.length ?? 0;
      final coverUrl = coverPhotoId != null
          ? 'https://picsum.photos/id/$coverPhotoId/600/800'
          : null;
      return {
        'albumId': id,
        'title': title,
        'description': description ?? '',
        'coverPhotoUrl': coverUrl,
        'photoCount': count,
        'createdAt': DateTime.now().toIso8601String(),
      };
    }

    final res = await http.post(
      _uri('/api/albums'),
      headers: _headersJson(),
      body: jsonEncode({
        'title': title,
        if (description != null) 'description': description,
        if (coverPhotoId != null) 'coverPhotoId': coverPhotoId,
        if (photoIdList != null) 'photoIdList': photoIdList,
      }),
    );

    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create album (${res.statusCode})');
  }

  // POST /api/albums/{albumId}/photos
  static Future<void> addPhotos({
    required int albumId,
    required List<int> photoIds,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return;
    }

    final res = await http.post(
      _uri('/api/albums/$albumId/photos'),
      headers: _headersJson(),
      body: jsonEncode({'photoIdList': photoIds}),
    );

    if (res.statusCode == 200 || res.statusCode == 204) return;
    throw Exception('Failed to add photos (${res.statusCode})');
  }

  // DELETE /api/albums/{albumId}/photos
  static Future<void> removePhotos({
    required int albumId,
    required List<int> photoIds,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return;
    }

    final req = http.Request('DELETE', _uri('/api/albums/$albumId/photos'));
    req.headers.addAll(_headersJson());
    req.body = jsonEncode({'photoIdList': photoIds});
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200 || res.statusCode == 204) return;
    throw Exception('Failed to remove photos (${res.statusCode})');
  }

  // GET /api/albums/{albumId}
  static Future<Map<String, dynamic>> getAlbum(int albumId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'albumId': albumId,
        'title': '2025 여름방학',
        'description': '친구들과의 소중한 여름 기록',
        'coverPhotoUrl': 'https://picsum.photos/seed/album$albumId/600/800',
        'photoCount': 6,
        'createdAt': DateTime.now().toIso8601String(),
        'photoIdList': [1001, 1002, 1003, 1004, 1005, 1006],
        'photoList': [
          {
            'photoId': 1001,
            'imageUrl': 'https://picsum.photos/seed/nemo1/600/800',
            'takenAt': '2025-07-20T14:00:00',
            'location': '홍대 포토그레이',
            'brand': '인생네컷',
          },
          {
            'photoId': 1002,
            'imageUrl': 'https://picsum.photos/seed/nemo2/600/800',
            'takenAt': '2025-07-21T13:30:00',
            'location': '강남 포토시그널',
            'brand': '포토시그널',
          },
          {
            'photoId': 1003,
            'imageUrl': 'https://picsum.photos/seed/nemo3/600/800',
            'takenAt': '2025-07-22T10:10:00',
            'location': '연남 포토그레이',
            'brand': '포토그레이',
          },
          {
            'photoId': 1004,
            'imageUrl': 'https://picsum.photos/seed/nemo4/600/800',
            'takenAt': '2025-07-22T15:20:00',
            'location': '서면 포토이즘',
            'brand': '포토이즘',
          },
          {
            'photoId': 1005,
            'imageUrl': 'https://picsum.photos/seed/nemo5/600/800',
            'takenAt': '2025-07-23T09:40:00',
            'location': '부산 인생네컷',
            'brand': '인생네컷',
          },
          {
            'photoId': 1006,
            'imageUrl': 'https://picsum.photos/seed/nemo6/600/800',
            'takenAt': '2025-07-24T18:05:00',
            'location': '대구 포토이즘',
            'brand': '포토이즘',
          },
        ],
      };
    }
    final res = await http.get(
      _uri('/api/albums/$albumId'),
      headers: _headersJson(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch album (${res.statusCode})');
  }

  // PUT /api/albums/{albumId}/cover
  static Future<void> setCoverPhoto({
    required int albumId,
    required int photoId,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return;
    }
    final res = await http.put(
      _uri('/api/albums/$albumId/cover'),
      headers: _headersJson(),
      body: jsonEncode({'photoId': photoId}),
    );
    if (res.statusCode == 200 || res.statusCode == 204) return;
    throw Exception('Failed to set cover (${res.statusCode})');
  }

  // PUT /api/albums/{albumId}
  static Future<Map<String, dynamic>> updateAlbum({
    required int albumId,
    String? title,
    String? description,
    int? coverPhotoId,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (coverPhotoId != null && coverPhotoId < 0) {
        throw Exception('INVALID_COVER_PHOTO');
      }
      return {'albumId': albumId, 'message': '앨범 정보가 성공적으로 수정되었습니다.'};
    }
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (coverPhotoId != null) body['coverPhotoId'] = coverPhotoId;

    final res = await http.put(
      _uri('/api/albums/$albumId'),
      headers: _headersJson(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else if (res.statusCode == 403) {
      throw Exception('FORBIDDEN');
    } else if (res.statusCode == 404) {
      throw Exception('ALBUM_NOT_FOUND');
    } else if (res.statusCode == 400) {
      throw Exception('INVALID_COVER_PHOTO');
    }
    throw Exception('Failed to update album (${res.statusCode})');
  }

  // DELETE /api/albums/{albumId}
  static Future<Map<String, dynamic>> deleteAlbum(int albumId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {'albumId': albumId, 'message': '앨범이 성공적으로 삭제되었습니다.'};
    }
    final res = await http.delete(
      _uri('/api/albums/$albumId'),
      headers: _headersJson(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 204) {
      return {'albumId': albumId, 'message': '앨범이 성공적으로 삭제되었습니다.'};
    }
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode == 404) throw Exception('ALBUM_NOT_FOUND');
    throw Exception('Failed to delete album (${res.statusCode})');
  }
}
