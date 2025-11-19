import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../app/constants.dart';
import 'auth_service.dart';

class PhotoUploadApi {
  static Uri _endpoint(String path) => Uri.parse('${AuthService.baseUrl}$path');

  /// QR 임시 등록 (QR 코드로 이미지 가져오기 + 미리보기용 imageUrl 반환)
  /// 명세서: POST /api/photos/qr-import
  Future<Map<String, dynamic>> qrImport({
    required String qrCode,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      // 간단 검증
      if (qrCode.trim().isEmpty) {
        throw Exception('유효하지 않은 QR 코드입니다.');
      }
      // 중복 업로드 모킹 (특정 QR은 이미 업로드된 것으로 처리)
      if (qrCode.contains('DUPLICATE')) {
        throw Exception('이미 업로드된 QR 코드입니다.');
      }
      // 만료된 QR 모킹
      if (qrCode.contains('EXPIRED')) {
        throw Exception('해당 QR 코드는 만료되었습니다.');
      }
      return {
        'photoId': DateTime.now().millisecondsSinceEpoch,
        'imageUrl': 'https://cdn.nemo.app/photos/qr_photo.jpg',
        'takenAt': DateTime.now().toIso8601String(),
        'location': '홍대 포토그레이',
        'brand': '인생네컷',
        'status': 'DRAFT',
      };
    }

    final uri = _endpoint('/api/photos/qr-import');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${AuthService.accessToken ?? ''}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'qrCode': qrCode,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    // 에러 처리
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    final errorCode = body['error'] as String?;
    final errorMessage = body['message'] as String?;

    if (response.statusCode == 400) {
      if (errorCode == 'INVALID_QR') {
        throw Exception(errorMessage ?? '유효하지 않은 QR 코드입니다.');
      }
      throw Exception(errorMessage ?? '잘못된 요청입니다.');
    }
    if (response.statusCode == 404) {
      if (errorCode == 'EXPIRED_QR') {
        throw Exception(errorMessage ?? '해당 QR 코드는 만료되었습니다.');
      }
      throw Exception(errorMessage ?? 'QR 코드를 찾을 수 없습니다.');
    }
    if (response.statusCode == 409) {
      if (errorCode == 'DUPLICATE_QR') {
        throw Exception(errorMessage ?? '이미 업로드된 QR 코드입니다.');
      }
      throw Exception(errorMessage ?? '중복된 요청입니다.');
    }
    if (response.statusCode == 502) {
      if (errorCode == 'QR_PROVIDER_ERROR') {
        throw Exception(errorMessage ?? 'QR 제공 서버에서 사진을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.');
      }
      throw Exception(errorMessage ?? '서버 오류가 발생했습니다.');
    }
    if (response.statusCode == 401) {
      throw Exception(errorMessage ?? '로그인이 필요합니다.');
    }
    throw Exception(errorMessage ?? 'QR 임시 등록 실패 (${response.statusCode})');
  }

  /// 사진 업로드 (QR 기반). 모킹 모드 지원.
  /// 명세서: QR 코드만 전달하면 백엔드에서 이미지를 처리
  Future<Map<String, dynamic>> uploadPhotoViaQr({
    required String qrCode,
    File? imageFile, // QR 코드만 있으면 null 가능 (백엔드에서 QR 코드 기반으로 이미지 처리)
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
      // 이미지 파일이 있으면 검증, 없으면 백엔드에서 처리
      if (imageFile != null && !await imageFile.exists()) {
        throw Exception('IMAGE_NOT_FOUND');
      }
      // 중복 업로드 모킹 (특정 QR은 이미 업로드된 것으로 처리)
      if (qrCode.contains('DUPLICATE')) {
        throw Exception('DUPLICATE_QR');
      }
      return {
        'photoId': DateTime.now().millisecondsSinceEpoch,
        'imageUrl': imageFile?.path ?? 'https://cdn.nemo.app/photos/qr_photo.jpg',
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
    
    // 이미지 파일이 있는 경우에만 추가 (QR 코드만 있으면 백엔드에서 처리)
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
    }

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

  /// 갤러리에서 사진 업로드 (QR 없음). 모킹 모드 지원.
  Future<Map<String, dynamic>> uploadPhotoFromGallery({
    required File imageFile,
    String? takenAtIso,
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
      // 간단 검증
      if (!await imageFile.exists()) {
        throw Exception('IMAGE_REQUIRED');
      }
      return {
        'photoId': DateTime.now().millisecondsSinceEpoch,
        'imageUrl': imageFile.path,
        'takenAt': takenAtIso ?? DateTime.now().toIso8601String(),
        'location': location ?? '',
        'brand': brand ?? '',
        'tagList': tagList ?? [],
        'friendList': [],
        'memo': memo,
        'source': 'GALLERY',
      };
    }

    final uri = _endpoint('/api/photos/gallery');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] =
        'Bearer ${AuthService.accessToken ?? ''}';
    
    // 이미지는 필수
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );
    
    // 나머지 필드는 선택사항이므로 값이 있을 때만 추가
    if (takenAtIso != null && takenAtIso.isNotEmpty) {
      request.fields['takenAt'] = takenAtIso;
    }
    if (location != null && location.isNotEmpty) {
      request.fields['location'] = location;
    }
    if (brand != null && brand.isNotEmpty) {
      request.fields['brand'] = brand;
    }
    if (tagList != null && tagList.isNotEmpty) {
      request.fields['tagList'] = jsonEncode(tagList);
    }
    if (friendIdList != null && friendIdList.isNotEmpty) {
      request.fields['friendIdList'] = jsonEncode(friendIdList);
    }
    if (memo != null && memo.isNotEmpty) {
      request.fields['memo'] = memo;
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 400) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final errorCode = body['error'] as String?;
      final errorMessage = body['message'] as String?;
      
      if (errorCode == 'IMAGE_REQUIRED') {
        throw Exception(errorMessage ?? '사진 파일은 필수입니다.');
      }
      if (errorCode == 'INVALID_DATE_FORMAT') {
        throw Exception(errorMessage ?? '촬영 날짜 형식이 잘못되었습니다. ISO 8601 형식을 사용해주세요.');
      }
      if (errorCode == 'INVALID_FRIEND_ID_LIST') {
        throw Exception(errorMessage ?? 'friendIdList는 숫자 배열(JSON) 형식이어야 합니다.');
      }
      throw Exception(errorMessage ?? '잘못된 요청입니다. (400)');
    }
    throw Exception('업로드 실패 (${response.statusCode})');
  }
}
