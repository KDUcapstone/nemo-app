import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../app/constants.dart';
import 'auth_service.dart';

class PhotoUploadApi {
  static Uri _endpoint(String path) => Uri.parse('${AuthService.baseUrl}$path');

  /// A) 파일 직접 업로드
  Future<Map<String, dynamic>> uploadPhotoFile({
    required File imageFile,
    required String takenAtIso,
    String? location,
    String? brand,
    List<String>? tagList,
    List<int>? friendIdList,
    String? memo,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (!await imageFile.exists()) {
        throw Exception('IMAGE_NOT_FOUND');
      }
      return {
        'photoId': DateTime.now().millisecondsSinceEpoch,
        'imageUrl': imageFile.path,
        'takenAt': takenAtIso,
        'location': location ?? '',
        'brand': brand ?? '',
        'tagList': tagList ?? [],
        'friendList': [],
        'memo': memo ?? '',
      };
    }

    final uri = _endpoint('/api/photos');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] =
    'Bearer ${AuthService.accessToken ?? ''}';

    request.fields['takenAt'] = takenAtIso;
    if (location != null) request.fields['location'] = location;
    if (brand != null) request.fields['brand'] = brand;
    if (tagList != null) request.fields['tagList'] = jsonEncode(tagList);
    if (friendIdList != null) {
      request.fields['friendIdList'] = jsonEncode(friendIdList);
    }
    if (memo != null) request.fields['memo'] = memo;

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    // ignore: avoid_print
    print('[UPLOAD(FILE)][status]=${response.statusCode}');
    // ignore: avoid_print
    print('[UPLOAD(FILE)][raw]=${response.body}');

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 400 || response.statusCode == 404) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(body['message'] ?? '잘못된 요청입니다.');
    }
    if (response.statusCode == 409) {
      throw Exception('이미 업로드된 QR입니다.');
    }
    throw Exception('업로드 실패 (${response.statusCode})');
  }

  /// B) QR/URL 업로드 (파일 첨부 금지) — 백엔드가 URL을 따라가서 저장
  /// [imageFile]은 과거 시그니처 호환용이며 **무시**된다.
  Future<Map<String, dynamic>> uploadPhotoViaQr({
    required String qrCode,
    required String takenAtIso,
    String? location,
    String? brand,
    List<String>? tagList,
    List<int>? friendIdList,
    String? memo,

    // ── backward compatibility only ──
    File? imageFile, // ignore: unused_element, deprecated_member_use_from_same_package
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (qrCode.trim().isEmpty) throw Exception('INVALID_QR');
      if (qrCode.contains('DUPLICATE')) throw Exception('DUPLICATE_QR');
      return {
        'photoId': DateTime.now().millisecondsSinceEpoch,
        'imageUrl': 'mock://qr',
        'takenAt': takenAtIso,
        'location': location ?? '',
        'brand': brand ?? '',
        'tagList': tagList ?? [],
        'friendList': [],
        'memo': memo ?? '',
      };
    }

    final uri = _endpoint('/api/photos');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] =
    'Bearer ${AuthService.accessToken ?? ''}';

    // ⚠️ 파일 없이 필드만 보냄
    request.fields['qrCode'] = qrCode;
    request.fields['takenAt'] = takenAtIso;
    if (location != null) request.fields['location'] = location;
    if (brand != null) request.fields['brand'] = brand;
    if (tagList != null) request.fields['tagList'] = jsonEncode(tagList);
    if (friendIdList != null) {
      request.fields['friendIdList'] = jsonEncode(friendIdList);
    }
    if (memo != null) request.fields['memo'] = memo;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    // ignore: avoid_print
    print('[UPLOAD(QR)][status]=${response.statusCode}');
    // ignore: avoid_print
    print('[UPLOAD(QR)][raw]=${response.body}');

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 400 || response.statusCode == 404) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(body['message'] ?? '잘못된 또는 만료된 QR입니다.');
    }
    if (response.statusCode == 409) {
      throw Exception('이미 업로드된 QR입니다.');
    }
    final msg = _safeMessage(response.body) ?? '업로드 실패';
    throw Exception('$msg (${response.statusCode})');
  }

  String? _safeMessage(String body) {
    try {
      if (body.isEmpty) return null;
      final m = jsonDecode(body);
      if (m is Map && m['message'] is String) return m['message'] as String;
      return null;
    } catch (_) {
      return null;
    }
  }
}
