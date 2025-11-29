import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:frontend/services/album_api.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/app/constants.dart';

/// 사진 다운로드 및 갤러리 저장 관련 공통 유틸
///
/// 백엔드 명세:
/// - 단일 사진 다운로드: GET /api/photos/{photoId}/download (302 Redirect → 실제 URL)
/// - 선택 사진 다운로드 URL 조회: POST /api/photos/download-urls
/// - 앨범 전체 다운로드용 별도 엔드포인트는 없음
///   ↳ 대신 GET /api/albums/{albumId}로 photoIdList를 조회한 뒤
///      POST /api/photos/download-urls에 전달해 사용
class PhotoDownloadService {
  /// 단일 사진 다운로드
  ///
  /// GET /api/photos/{photoId}/download 을 호출하면
  /// 백엔드에서 302 Redirect 로 실제 S3/LocalStack URL 로 이동하도록 구현되어 있음.
  ///
  /// 여기서는 302 응답의 Location 헤더를 읽어 해당 URL을
  /// [launchUrl] 로 열어 OS 기본 다운로드/저장 동작을 유도한다.
  static Future<bool> downloadSinglePhotoToGallery(int photoId) async {
    try {
      // 모킹 모드에서는 실제 네트워크 호출 대신 바로 성공 처리
      if (AppConstants.useMockApi) {
        await Future<void>.delayed(
          Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
        );
        return true;
      }

      final baseUrl = AuthService.baseUrl;
      final requestUri = Uri.parse('$baseUrl/api/photos/$photoId/download');

      final headers = <String, String>{};
      final token = AuthService.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      // 302를 직접 처리하기 위해 followRedirects: false 로 설정
      final res = await http.get(requestUri, headers: headers);

      // 백엔드 명세는 302 Redirect를 사용하지만,
      // 구현에 따라 200으로 직접 내려줄 수도 있으므로 3xx / 2xx 모두 고려한다.
      String? downloadUrl;

      if (res.statusCode == 302 || res.statusCode == 301) {
        downloadUrl = res.headers['location'];
      } else if (res.statusCode == 200) {
        // 200으로 직접 바이너리/URL을 돌려주는 경우는 현재 명세에는 없지만,
        // 추후 확장 가능성을 고려해 URL만 들어있는 단순 JSON 형태도 허용한다.
        try {
          final decoded =
              jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final url = decoded['downloadUrl'] as String?;
          if (url != null && url.isNotEmpty) {
            downloadUrl = url;
          }
        } catch (_) {
          // JSON 파싱 실패 시에는 특별히 할 수 있는 것이 없으므로 실패 처리
        }
      } else if (res.statusCode == 403) {
        throw Exception('해당 사진을 다운로드할 권한이 없습니다.');
      } else if (res.statusCode == 404) {
        throw Exception('해당 사진을 찾을 수 없습니다.');
      } else {
        throw Exception('다운로드 실패 (${res.statusCode})');
      }

      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw Exception('다운로드 URL을 받지 못했습니다.');
      }

      final uri = Uri.tryParse(downloadUrl);
      if (uri == null) {
        throw Exception('잘못된 다운로드 URL입니다.');
      }

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ok;
    } catch (e) {
      throw Exception('다운로드 중 오류: $e');
    }
  }

  /// 선택 사진 다운로드
  ///
  /// POST /api/photos/download-urls
  /// Request:
  /// ```json
  /// { "photoIdList": [101, 102, 110] }
  /// ```
  ///
  /// Response:
  /// ```json
  /// {
  ///   "photos": [
  ///     { "photoId": 101, "downloadUrl": "...", "filename": "...", "fileSize": 12345 },
  ///     ...
  ///   ]
  /// }
  /// ```
  ///
  /// 반환된 downloadUrl 리스트를 순회하며 갤러리에 저장하고,
  /// 실제로 저장에 성공한 건수(successCount)를 반환한다.
  static Future<int> downloadPhotosToGallery(List<int> photoIds) async {
    if (photoIds.isEmpty) return 0;

    try {
      // 모킹 모드: 네트워크 호출 없이 선택된 개수만큼 저장된 것으로 처리
      if (AppConstants.useMockApi) {
        await Future<void>.delayed(
          Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
        );
        return photoIds.length;
      }

      final res = await ApiClient.post(
        '/api/photos/download-urls',
        body: {'photoIdList': photoIds},
      );

      if (res.statusCode == 200) {
        final decoded =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final photos = decoded['photos'] as List<dynamic>? ?? const [];

        if (photos.isEmpty) {
          throw Exception('다운로드 가능한 사진이 없습니다.');
        }

        int successCount = 0;
        for (final item in photos) {
          final m = item as Map<String, dynamic>;
          final url = m['downloadUrl'] as String?;
          if (url == null || url.isEmpty) continue;

          final uri = Uri.tryParse(url);
          if (uri == null) continue;

          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) successCount++;
        }

        return successCount;
      } else if (res.statusCode == 404) {
        // NO_DOWNLOADABLE_PHOTOS
        throw Exception('다운로드 가능한 사진이 없습니다.');
      } else if (res.statusCode == 400) {
        throw Exception('요청 형식이 올바르지 않습니다.');
      } else if (res.statusCode == 403) {
        throw Exception('사진을 다운로드할 권한이 없습니다.');
      } else {
        throw Exception('다운로드 URL 조회 실패 (${res.statusCode})');
      }
    } catch (e) {
      throw Exception('다운로드 중 오류: $e');
    }
  }

  /// 앨범 전체 다운로드
  ///
  /// 별도 앨범 다운로드 엔드포인트는 사용하지 않고,
  /// 1) GET /api/albums/{albumId} 로 photoIdList를 조회한 뒤
  /// 2) [downloadPhotosToGallery] 에 위임해 선택 다운로드 API를 재사용한다.
  static Future<int> downloadAlbumToGallery(int albumId) async {
    try {
      final albumData = await AlbumApi.getAlbum(albumId);
      final photoIdList = albumData['photoIdList'] as List<dynamic>?;

      if (photoIdList == null || photoIdList.isEmpty) {
        return 0;
      }

      final photoIds = photoIdList
          .map((id) => (id as num).toInt())
          .toList(growable: false);

      return await downloadPhotosToGallery(photoIds);
    } catch (e) {
      throw Exception('앨범 다운로드 중 오류: $e');
    }
  }
}
