import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:frontend/app/constants.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/api_client.dart';

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
      const names = ['인생네컷', '하루필름', '포토이즘', '포토그레이', '포토랩', '엑시트'];
      final mock = List.generate(6, (i) {
        final id = 20 - i;
        final title = names[i % names.length];
        return {
          'albumId': id,
          'title': title,
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

      // sort 파라미터에 따라 정렬 적용
      final sortedMock = List<Map<String, dynamic>>.from(mock);
      if (sort == 'createdAt,asc') {
        // 오래된순: createdAt 오름차순
        sortedMock.sort((a, b) {
          final aDate = DateTime.parse(a['createdAt'] as String);
          final bDate = DateTime.parse(b['createdAt'] as String);
          return aDate.compareTo(bDate);
        });
      } else if (sort == 'title,asc') {
        // 이름순: title 오름차순 (가나다순)
        sortedMock.sort((a, b) {
          final aTitle = (a['title'] as String?) ?? '';
          final bTitle = (b['title'] as String?) ?? '';
          return aTitle.compareTo(bTitle);
        });
      } else {
        // 기본값: createdAt,desc (최신순) - 이미 mock이 최신순으로 생성됨
        // 추가 정렬 불필요하지만 명시적으로 유지
        sortedMock.sort((a, b) {
          final aDate = DateTime.parse(a['createdAt'] as String);
          final bDate = DateTime.parse(b['createdAt'] as String);
          return bDate.compareTo(aDate);
        });
      }

      final start = page * size;
      final end = (start + size).clamp(0, sortedMock.length);
      final content = start < sortedMock.length
          ? sortedMock.sublist(start, end)
          : <Map<String, dynamic>>[];
      return {
        'content': content,
        'page': {
          'size': size,
          'totalElements': sortedMock.length,
          'totalPages': (sortedMock.length / size).ceil(),
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
    final res = await ApiClient.get('/api/albums', queryParameters: q);
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

  // POST /api/albums/{albumId}/favorite  -> { albumId, favorited: true, message }
  static Future<Map<String, dynamic>> favoriteAlbum(int albumId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'albumId': albumId,
        'favorited': true,
        'message': '앨범이 즐겨찾기에 추가되었습니다.',
      };
    }
    final res = await http.post(
      _uri('/api/albums/$albumId/favorite'),
      headers: _headersJson(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 404) throw Exception('ALBUM_NOT_FOUND');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    throw Exception('Failed to favorite album (${res.statusCode})');
  }

  // DELETE /api/albums/{albumId}/favorite -> { albumId, favorited: false, message }
  static Future<Map<String, dynamic>> unfavoriteAlbum(int albumId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'albumId': albumId,
        'favorited': false,
        'message': '앨범 즐겨찾기가 해제되었습니다.',
      };
    }
    final res = await http.delete(
      _uri('/api/albums/$albumId/favorite'),
      headers: _headersJson(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 404) throw Exception('ALBUM_NOT_FOUND');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    throw Exception('Failed to unfavorite album (${res.statusCode})');
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

  // GET /api/albums/share/requests -> PENDING 공유 요청 목록
  static Future<List<Map<String, dynamic>>> getShareRequests() async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return [
        {
          'albumId': 20,
          'albumTitle': '여름 제주 여행',
          'invitedBy': {'userId': 1, 'nickname': '앨범주인'},
          'invitedAt': DateTime.now().subtract(const Duration(minutes: 40)).toIso8601String(),
          'status': 'PENDING',
          'inviteRole': 'VIEWER',
        },
        {
          'albumId': 34,
          'albumTitle': '겨울 스키장',
          'invitedBy': {'userId': 8, 'nickname': '친구A'},
          'invitedAt': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
          'status': 'PENDING',
          'inviteRole': 'EDITOR',
        },
      ];
    }
    final res = await http.get(_uri('/api/albums/share/requests'), headers: _headersJson());
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    throw Exception('Failed to fetch share requests (${res.statusCode})');
  }

  // GET /api/albums/shared -> 내가 공유받은/공유 중인 앨범 목록(목업 포함 myRole)
  static Future<List<Map<String, dynamic>>> getSharedAlbums({
    int page = 0,
    int size = 10,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      final now = DateTime.now();
      return [
        {
          'albumId': 201,
          'title': '여름 제주 여행',
          'coverPhotoUrl': 'https://picsum.photos/seed/shared201/600/800',
          'photoCount': 24,
          'createdAt': now.subtract(const Duration(days: 10)).toIso8601String(),
          'myRole': 'VIEWER',
        },
        {
          'albumId': 202,
          'title': '겨울 스키장',
          'coverPhotoUrl': 'https://picsum.photos/seed/shared202/600/800',
          'photoCount': 12,
          'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
          'myRole': 'EDITOR',
        },
        {
          'albumId': 203,
          'title': '동아리 공연 아카이브',
          'coverPhotoUrl': null,
          'photoCount': 57,
          'createdAt': now.subtract(const Duration(days: 30)).toIso8601String(),
          'myRole': 'CO_OWNER',
        },
      ];
    }
    final res = await http.get(
      _uri('/api/albums/shared').replace(queryParameters: {'page': '$page', 'size': '$size'}),
      headers: _headersJson(),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is List) return body.cast<Map<String, dynamic>>();
      if (body is Map<String, dynamic>) {
        final List list = body['content'] ?? body['items'] ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return const <Map<String, dynamic>>[];
    }
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    throw Exception('Failed to fetch shared albums (${res.statusCode})');
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

  // POST /api/albums/{albumId}/thumbnail (JSON: { photoId })
  static Future<Map<String, dynamic>> setThumbnail({
    required int albumId,
    int? photoId,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'albumId': albumId,
        'thumbnailUrl': 'https://picsum.photos/seed/album${albumId}-thumb/600/800',
        'message': '앨범 썸네일이 성공적으로 설정되었습니다.',
      };
    }
    final uri = _uri('/api/albums/$albumId/thumbnail');
    final headers = _headersJson();
    final body = photoId != null ? jsonEncode({'photoId': photoId}) : null;
    final res = await http.post(uri, headers: headers, body: body);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 404) {
      final e = jsonDecode(res.body);
      final err = e is Map<String, dynamic> ? (e['error']?.toString() ?? '') : '';
      if (err == 'ALBUM_NOT_FOUND') throw Exception('ALBUM_NOT_FOUND');
      if (err == 'PHOTO_NOT_FOUND') throw Exception('PHOTO_NOT_FOUND');
      throw Exception('NOT_FOUND');
    }
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    throw Exception('Failed to set thumbnail (${res.statusCode})');
  }

  // POST /api/albums/{albumId}/thumbnail (multipart: file)
  static Future<Map<String, dynamic>> uploadThumbnailFile({
    required int albumId,
    required File file,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'albumId': albumId,
        'thumbnailUrl': 'https://picsum.photos/seed/album${albumId}-upload/600/800',
        'message': '앨범 썸네일이 성공적으로 설정되었습니다.',
      };
    }
    final uri = _uri('/api/albums/$albumId/thumbnail');
    final req = http.MultipartRequest('POST', uri);
    final token = AuthService.accessToken;
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 404) {
      final e = jsonDecode(res.body);
      final err = e is Map<String, dynamic> ? (e['error']?.toString() ?? '') : '';
      if (err == 'ALBUM_NOT_FOUND') throw Exception('ALBUM_NOT_FOUND');
      if (err == 'PHOTO_NOT_FOUND') throw Exception('PHOTO_NOT_FOUND');
      throw Exception('NOT_FOUND');
    }
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    throw Exception('Failed to upload thumbnail (${res.statusCode})');
  }

  // POST /api/albums/{albumId}/share/accept
  static Future<Map<String, dynamic>> acceptShare(int albumId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {'albumId': albumId, 'role': 'VIEWER', 'message': '앨범 공유를 수락했습니다.'};
    }
    final res = await http.post(_uri('/api/albums/$albumId/share/accept'), headers: _headersJson());
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 404) throw Exception('INVITE_NOT_FOUND');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode == 409) throw Exception('ALREADY_ACCEPTED');
    throw Exception('Failed to accept share (${res.statusCode})');
  }

  // POST /api/albums/{albumId}/share/reject
  static Future<Map<String, dynamic>> rejectShare(int albumId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {'albumId': albumId, 'message': '앨범 공유 요청을 거절했습니다.'};
    }
    final res = await http.post(_uri('/api/albums/$albumId/share/reject'), headers: _headersJson());
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 404) throw Exception('INVITE_NOT_FOUND');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    throw Exception('Failed to reject share (${res.statusCode})');
  }

  // GET /api/albums/{albumId}/share/members
  static Future<List<Map<String, dynamic>>> getShareMembers(int albumId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(Duration(milliseconds: AppConstants.simulatedNetworkDelayMs));
      return [
        {'userId': 1, 'nickname': '앨범주인', 'role': 'OWNER'},
        {'userId': 7, 'nickname': '네컷러버', 'role': 'EDITOR'},
        {'userId': 9, 'nickname': '하루필름', 'role': 'VIEWER'},
      ];
    }
    final res = await http.get(_uri('/api/albums/$albumId/share/members'), headers: _headersJson());
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    if (res.statusCode == 404) throw Exception('ALBUM_NOT_FOUND');
    throw Exception('Failed to fetch members (${res.statusCode})');
  }

  // PUT /api/albums/{albumId}/share/permission { targetUserId, role }
  static Future<Map<String, dynamic>> updateSharePermission({
    required int albumId,
    required int targetUserId,
    required String role, // VIEWER | EDITOR | CO_OWNER
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(Duration(milliseconds: AppConstants.simulatedNetworkDelayMs));
      if (!['VIEWER', 'EDITOR', 'CO_OWNER'].contains(role)) {
        throw Exception('INVALID_ROLE');
      }
      return {
        'albumId': albumId,
        'targetUserId': targetUserId,
        'role': role,
        'message': '공유 멤버 권한이 변경되었습니다.',
      };
    }
    final res = await http.put(
      _uri('/api/albums/$albumId/share/permission'),
      headers: _headersJson(),
      body: jsonEncode({'targetUserId': targetUserId, 'role': role}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 400) throw Exception('INVALID_ROLE');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    throw Exception('Failed to update permission (${res.statusCode})');
  }

  // DELETE /api/albums/{albumId}/share/{targetUserId}
  static Future<Map<String, dynamic>> removeShareMember({
    required int albumId,
    required int targetUserId,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(Duration(milliseconds: AppConstants.simulatedNetworkDelayMs));
      if (targetUserId == 1) throw Exception('CANNOT_REMOVE_OWNER');
      return {'albumId': albumId, 'removedUserId': targetUserId, 'message': '해당 사용자를 앨범에서 제거했습니다.'};
    }
    final res = await http.delete(_uri('/api/albums/$albumId/share/$targetUserId'), headers: _headersJson());
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 400) throw Exception('CANNOT_REMOVE_OWNER');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    throw Exception('Failed to remove member (${res.statusCode})');
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

  // POST /api/albums/{albumId}/share
  static Future<Map<String, dynamic>> shareAlbum({
    required int albumId,
    required List<int> friendIdList,
    String defaultRole = 'VIEWER',
    Map<int, String>? perUserRoles,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return {
        'albumId': albumId,
        'sharedTo': friendIdList
            .map((id) => {'userId': id, 'nickname': '친구$id'})
            .toList(),
        'message': '앨범이 선택한 친구들에게 성공적으로 공유되었습니다.',
      };
    }
    final res = await http.post(
      _uri('/api/albums/$albumId/share'),
      headers: _headersJson(),
      body: jsonEncode({'friendIdList': friendIdList}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 400) throw Exception('NOT_FRIEND');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode == 404) throw Exception('ALBUM_NOT_FOUND');
    throw Exception('Failed to share album (${res.statusCode})');
  }

  // POST /api/albums/{albumId}/share/link  -> { shareUrl }
  static Future<String> createShareLink(
    int albumId, {
    int? expiryHours,
    String permission = 'view',
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      final q = <String, String>{'perm': permission};
      if (expiryHours != null) q['exp'] = '$expiryHours';
      final query = q.entries.map((e) => '${e.key}=${e.value}').join('&');
      return 'https://nemo.app/share/albums/$albumId?token=mockToken&$query';
    }
    final res = await http.post(
      _uri('/api/albums/$albumId/share/link'),
      headers: _headersJson(),
      body: jsonEncode({
        if (expiryHours != null) 'expiryHours': expiryHours,
        'permission': permission,
      }),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['shareUrl'] as String;
    }
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode == 404) throw Exception('ALBUM_NOT_FOUND');
    throw Exception('Failed to create share link (${res.statusCode})');
  }

  // GET /api/albums/{albumId}/share/targets
  static Future<List<Map<String, dynamic>>> getShareTargets(int albumId) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      // 더미: 2명 공유 중
      return [
        {'userId': 3, 'nickname': '네컷러버'},
        {'userId': 5, 'nickname': '사진장인'},
      ];
    }
    final res = await http.get(
      _uri('/api/albums/$albumId/share/targets'),
      headers: _headersJson(),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final List list = body['sharedTo'] ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode == 404) throw Exception('ALBUM_NOT_FOUND');
    throw Exception('Failed to fetch share targets (${res.statusCode})');
  }

  // DELETE /api/albums/{albumId}/share/{userId}
  static Future<void> unshareTarget({
    required int albumId,
    required int userId,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      return;
    }
    final res = await http.delete(
      _uri('/api/albums/$albumId/share/$userId'),
      headers: _headersJson(),
    );
    if (res.statusCode == 200 || res.statusCode == 204) return;
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode == 404) throw Exception('ALBUM_NOT_FOUND');
    throw Exception('Failed to unshare (${res.statusCode})');
  }
}

extension AlbumSharing on AlbumApi {
  // POST /api/albums/{albumId}/share
  static Future<Map<String, dynamic>> shareAlbum({
    required int albumId,
    required List<int> friendIdList,
    String defaultRole = 'VIEWER',
    Map<int, String>? perUserRoles,
  }) async {
    return AlbumApi.shareAlbum(
      albumId: albumId,
      friendIdList: friendIdList,
      defaultRole: defaultRole,
      perUserRoles: perUserRoles,
    );
  }

  // POST /api/albums/{albumId}/share-url (가정) → 공유 URL 생성
  static Future<Map<String, dynamic>> generateShareUrl({
    required int albumId,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      final url =
          'https://nemo.app/share/$albumId/${DateTime.now().millisecondsSinceEpoch}';
      return {'albumId': albumId, 'url': url, 'message': '공유 URL이 생성되었습니다.'};
    }
    final res = await ApiClient.post('/api/albums/$albumId/share-url');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode == 404) throw Exception('ALBUM_NOT_FOUND');
    throw Exception('Failed to create share url (${res.statusCode})');
  }
}
