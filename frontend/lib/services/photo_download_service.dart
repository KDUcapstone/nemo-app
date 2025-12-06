import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:frontend/services/album_api.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/app/constants.dart';

/// 사진 다운로드 및 갤러리 저장 관련 공통 유틸
///
/// 백엔드 명세:
/// - 단일 사진 다운로드: GET /api/photos/{photoId}/download (바이너리 응답)
/// - 선택 사진 다운로드 URL 조회: POST /api/photos/download-urls
/// - 앨범 전체 다운로드 URL 조회: GET /api/albums/{albumId}/download-urls
class PhotoDownloadService {
  /// 단일 사진 다운로드
  ///
  /// GET /api/photos/{photoId}/download
  /// 명세: 바이너리 응답 (200 OK, Content-Type: image/jpeg)
  static Future<bool> downloadSinglePhotoToGallery(int photoId) async {
    try {
      if (AppConstants.useMockApi) {
        await Future<void>.delayed(
          Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
        );
        return true;
      }

      // 권한 확인
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.photos.status;
        if (!status.isGranted) {
          final result = await Permission.photos.request();
          if (!result.isGranted) {
            throw Exception('갤러리 접근 권한이 필요합니다.');
          }
        }
      }

      final baseUrl = AuthService.baseUrl;
      final requestUri = Uri.parse('$baseUrl/api/photos/$photoId/download');

      final headers = <String, String>{};
      final token = AuthService.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      // 바이너리 응답 받기
      final res = await http.get(requestUri, headers: headers);

      if (res.statusCode == 200) {
        // Content-Disposition에서 파일명 추출
        final contentDisposition = res.headers['content-disposition'];
        String? filename;
        if (contentDisposition != null) {
          final match = RegExp(
            r'filename="?([^"]+)"?',
          ).firstMatch(contentDisposition);
          if (match != null) {
            filename = match.group(1);
          }
        }
        filename ??= 'nemo_$photoId.jpg';

        // 임시 디렉토리에 저장
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(res.bodyBytes);

        // 갤러리에 저장
        final result = await ImageGallerySaverPlus.saveFile(file.path);
        if (result['isSuccess'] == true) {
          return true;
        } else {
          throw Exception('갤러리 저장 실패');
        }
      } else if (res.statusCode == 403) {
        throw Exception('해당 사진을 다운로드할 권한이 없습니다.');
      } else if (res.statusCode == 404) {
        throw Exception('해당 사진을 찾을 수 없습니다.');
      } else {
        throw Exception('다운로드 실패 (${res.statusCode})');
      }
    } catch (e) {
      throw Exception('다운로드 중 오류: $e');
    }
  }

  /// 선택 사진 다운로드
  ///
  /// POST /api/photos/download-urls
  static Future<int> downloadPhotosToGallery(List<int> photoIds) async {
    if (photoIds.isEmpty) return 0;

    try {
      if (AppConstants.useMockApi) {
        await Future<void>.delayed(
          Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
        );
        return photoIds.length;
      }

      // 권한 확인
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.photos.status;
        if (!status.isGranted) {
          final result = await Permission.photos.request();
          if (!result.isGranted) {
            throw Exception('갤러리 접근 권한이 필요합니다.');
          }
        }
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

          try {
            // Pre-signed URL에서 다운로드
            final downloadRes = await http.get(Uri.parse(url));
            if (downloadRes.statusCode == 200) {
              final filename =
                  m['filename'] as String? ?? 'nemo_${m['photoId']}.jpg';

              // 임시 디렉토리에 저장
              final tempDir = await getTemporaryDirectory();
              final file = File('${tempDir.path}/$filename');
              await file.writeAsBytes(downloadRes.bodyBytes);

              // 갤러리에 저장
              final result = await ImageGallerySaverPlus.saveFile(file.path);
              if (result['isSuccess'] == true) {
                successCount++;
              }
            }
          } catch (e) {
            // 개별 다운로드 실패는 무시하고 계속 진행
            continue;
          }
        }

        return successCount;
      } else if (res.statusCode == 404) {
        // NO_DOWNLOADABLE_PHOTOS
        throw Exception('다운로드 가능한 사진이 없습니다.');
      } else if (res.statusCode == 403) {
        // 권한 없음 (명세서에 따라 403도 처리)
        throw Exception('사진을 다운로드할 권한이 없습니다.');
      } else if (res.statusCode == 400) {
        throw Exception('요청 형식이 올바르지 않습니다.');
      } else {
        throw Exception('다운로드 URL 조회 실패 (${res.statusCode})');
      }
    } catch (e) {
      throw Exception('다운로드 중 오류: $e');
    }
  }

  /// 앨범 전체 다운로드
  ///
  /// GET /api/albums/{albumId}/download-urls (명세서에 따른 전용 엔드포인트 사용)
  static Future<int> downloadAlbumToGallery(int albumId) async {
    try {
      if (AppConstants.useMockApi) {
        await Future<void>.delayed(
          Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
        );
        return 5; // 모킹: 임의 개수
      }

      // 권한 확인
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.photos.status;
        if (!status.isGranted) {
          final result = await Permission.photos.request();
          if (!result.isGranted) {
            throw Exception('갤러리 접근 권한이 필요합니다.');
          }
        }
      }

      // 명세서에 따른 전용 엔드포인트 사용
      final downloadUrlsData = await AlbumApi.getAlbumDownloadUrls(albumId);
      final photos = downloadUrlsData['photos'] as List<dynamic>? ?? const [];

      if (photos.isEmpty) {
        return 0;
      }

      int successCount = 0;
      for (final item in photos) {
        final m = item as Map<String, dynamic>;
        final url = m['downloadUrl'] as String?;
        if (url == null || url.isEmpty) continue;

        try {
          // Pre-signed URL에서 다운로드
          final downloadRes = await http.get(Uri.parse(url));
          if (downloadRes.statusCode == 200) {
            final filename =
                m['filename'] as String? ?? 'nemo_${m['photoId']}.jpg';

            // 임시 디렉토리에 저장
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/$filename');
            await file.writeAsBytes(downloadRes.bodyBytes);

            // 갤러리에 저장
            final result = await ImageGallerySaverPlus.saveFile(file.path);
            if (result['isSuccess'] == true) {
              successCount++;
            }
          }
        } catch (e) {
          // 개별 다운로드 실패는 무시하고 계속 진행
          continue;
        }
      }

      return successCount;
    } catch (e) {
      if (e.toString().contains('ALBUM_NOT_FOUND')) {
        throw Exception('해당 앨범을 찾을 수 없습니다.');
      } else if (e.toString().contains('권한이 없습니다')) {
        throw Exception('해당 앨범의 사진을 다운로드할 권한이 없습니다.');
      }
      throw Exception('앨범 다운로드 중 오류: $e');
    }
  }
}
