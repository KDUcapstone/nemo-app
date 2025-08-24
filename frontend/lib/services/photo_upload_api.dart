import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../app/constants.dart';
import 'auth_service.dart';

class PhotoUploadApi {
  static Uri _endpoint(String path) => Uri.parse('${AuthService.baseUrl}$path');

  /// 사진 업로드 (QR 기반). 모킹 모드 지원.
  Future<Map<String, dynamic>> uploadPhotoViaQr({
    required String qrCode,
    required File imageFile,
    required String takenAtIso,
    required String location,
    required String brand,
    List<String>? tagList,
    List<int>? friendIdList,
    String? memo,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      // 간단 검증
      if (qrCode.trim().isEmpty) {
        throw Exception('INVALID_QR');
      }
      if (!await imageFile.exists()) {
        throw Exception('IMAGE_NOT_FOUND');
      }
      // 중복 업로드 모킹 (특정 QR은 이미 업로드된 것으로 처리)
      if (qrCode.contains('DUPLICATE')) {
        throw Exception('DUPLICATE_QR');
      }
      return {
        'photoId': DateTime.now().millisecondsSinceEpoch,
        'imageUrl': imageFile.path,
        'takenAt': takenAtIso,
        'location': location,
        'brand': brand,
        'tagList': tagList ?? [],
        'friendList': [],
        'memo': memo,
      };
    }

    final uri = _endpoint('/api/photos');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] =
        'Bearer ${AuthService.accessToken ?? ''}';
    request.fields['qrCode'] = qrCode;
    request.fields['takenAt'] = takenAtIso;
    request.fields['location'] = location;
    request.fields['brand'] = brand;
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
    throw Exception('업로드 실패 (${response.statusCode})');
  }
}
