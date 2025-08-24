import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/app/constants.dart';
import 'auth_service.dart';

class PhotoApi {
  static Uri _u(String p) => Uri.parse('${AuthService.baseUrl}$p');

  Future<List<Map<String, dynamic>>> getPhotos({
    bool? favorite,
    String? tag,
    String? sort,
    int? page,
    int? size,
  }) async {
    if (AppConstants.useMockApi) {
      // 실제 목록은 Provider 더미를 사용. 빈 배열 반환해 Provider 상태에 맡김
      return [];
    }
    final qp = <String, String>{};
    if (favorite != null) qp['favorite'] = favorite.toString();
    if (tag != null && tag.isNotEmpty) qp['tag'] = tag;
    if (sort != null && sort.isNotEmpty) qp['sort'] = sort;
    if (page != null) qp['page'] = page.toString();
    if (size != null) qp['size'] = size.toString();

    final uri = Uri.parse(
      '${AuthService.baseUrl}/api/photos',
    ).replace(queryParameters: qp.isEmpty ? null : qp);
    final r = await http.get(uri, headers: _h());
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      if (body is List) {
        // 하위 호환: 배열로 바로 오는 경우
        return body.cast<Map<String, dynamic>>();
      }
      if (body is Map && body['content'] is List) {
        final list = (body['content'] as List).cast<Map<String, dynamic>>();
        return list;
      }
      throw Exception('응답 형식 오류: content 배열 없음');
    }
    if (r.statusCode == 401) {
      throw Exception('인증이 필요합니다. (401)');
    }
    throw Exception('목록 조회 실패 (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getPhoto(int photoId) async {
    if (AppConstants.useMockApi) {
      return {
        'photoId': photoId,
        'imageUrl': 'https://picsum.photos/seed/detail$photoId/800/1066',
        'takenAt': DateTime.now().toIso8601String(),
        'location': '모킹 위치',
        'brand': '모킹 브랜드',
        'tagList': <String>['모킹', '샘플'],
        'friendList': [
          {
            'userId': 3,
            'nickname': '네컷러버',
            'profileImageUrl': 'https://picsum.photos/seed/friend3/100/100',
          },
          {'userId': 5, 'nickname': '사진장인', 'profileImageUrl': null},
        ],
        'memo': '모킹 상세 메모',
        'isFavorite': true,
        'favorite': true,
        'owner': {
          'userId': 1,
          'nickname': '나',
          'profileImageUrl': 'https://picsum.photos/seed/owner/100/100',
        },
      };
    }
    final r = await http.get(_u('/api/photos/$photoId'), headers: _h());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 403) {
      throw Exception('접근 권한이 없습니다. (403)');
    }
    if (r.statusCode == 404) {
      throw Exception('사진을 찾을 수 없습니다. (404)');
    }
    throw Exception('상세 조회 실패 (${r.statusCode})');
  }

  Future<Map<String, dynamic>> updatePhoto(
    int photoId, {
    List<String>? tagList,
    String? memo,
    List<int>? friendIdList,
    bool? isFavorite,
  }) async {
    if (AppConstants.useMockApi) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return {
        'photoId': photoId,
        'message': '사진 정보가 성공적으로 수정되었습니다.',
        // 편의상 프론트 상태 갱신을 위해 일부 필드 에코
        if (tagList != null) 'tagList': tagList,
        if (memo != null) 'memo': memo,
        if (isFavorite != null) 'isFavorite': isFavorite,
        if (friendIdList != null) 'friendIdList': friendIdList,
      };
    }
    final body = <String, dynamic>{};
    if (tagList != null) body['tagList'] = tagList;
    if (memo != null) body['memo'] = memo;
    if (friendIdList != null) body['friendIdList'] = friendIdList;
    if (isFavorite != null) body['isFavorite'] = isFavorite;
    final r = await http.put(
      _u('/api/photos/$photoId'),
      headers: _h(json: true),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 403) {
      throw Exception('수정 권한이 없습니다. (403)');
    }
    if (r.statusCode == 404) {
      throw Exception('사진이 존재하지 않습니다. (404)');
    }
    throw Exception('수정 실패 (${r.statusCode})');
  }

  Future<Map<String, dynamic>> deletePhoto(int photoId) async {
    if (AppConstants.useMockApi) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return {'photoId': photoId, 'message': '사진이 성공적으로 삭제되었습니다.'};
    }
    final r = await http.delete(_u('/api/photos/$photoId'), headers: _h());
    if (r.statusCode == 200 || r.statusCode == 204) {
      try {
        final body = r.body.isNotEmpty ? jsonDecode(r.body) : {};
        if (body is Map<String, dynamic>) return body;
      } catch (_) {}
      return {'photoId': photoId, 'message': '사진이 성공적으로 삭제되었습니다.'};
    }
    if (r.statusCode == 403) {
      throw Exception('삭제 권한이 없습니다. (403)');
    }
    if (r.statusCode == 404) {
      throw Exception('해당 사진을 찾을 수 없습니다. (404)');
    }
    throw Exception('삭제 실패 (${r.statusCode})');
  }

  Future<bool> toggleFavorite(
    int photoId, {
    required bool currentFavorite,
  }) async {
    if (AppConstants.useMockApi) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      // 모킹: 현재 상태의 반대값을 최종 상태로 반환
      return !currentFavorite;
    }
    final r = await http.post(
      _u('/api/photos/$photoId/favorite'),
      headers: _h(),
    );
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      // 사양: isFavorite 필드 사용
      if (body is Map && body.containsKey('isFavorite')) {
        return body['isFavorite'] == true;
      }
      // 하위호환: favorite 키가 올 수도 있음
      if (body is Map && body.containsKey('favorite')) {
        return body['favorite'] == true;
      }
      // 파싱 실패 시 예외
      throw Exception('응답 파싱 실패: isFavorite 누락');
    }
    if (r.statusCode == 403) {
      throw Exception('즐겨찾기 권한이 없습니다. (403)');
    }
    if (r.statusCode == 404) {
      throw Exception('해당 사진을 찾을 수 없습니다. (404)');
    }
    throw Exception('즐겨찾기 토글 실패 (${r.statusCode})');
  }

  Map<String, String> _h({bool json = false}) {
    final h = <String, String>{
      'Authorization': 'Bearer ${AuthService.accessToken ?? ''}',
    };
    if (json) h['Content-Type'] = 'application/json';
    return h;
  }
}
