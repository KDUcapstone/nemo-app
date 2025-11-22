import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../app/constants.dart';
import 'auth_service.dart';

class PhotoUploadApi {
  static Uri _endpoint(String path) => Uri.parse('${AuthService.baseUrl}$path');

  /// POST /api/photos - 파일 직접 업로드 (레거시, 명세서에는 없음)
  /// 명세서 기준으로는 POST /api/photos/gallery를 사용해야 함
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

  /// POST /api/photos/qr-import - QR 임시 등록 API
  /// API 명세서: QR 코드만 받아서 백엔드가 사진을 가져오고 임시 등록
  Future<Map<String, dynamic>> importPhotoFromQr({
    required String qrCode,
  }) async {
    if (AppConstants.useMockApi) {
      await Future.delayed(
        Duration(milliseconds: AppConstants.simulatedNetworkDelayMs),
      );
      if (qrCode.trim().isEmpty) throw Exception('INVALID_QR');
      if (qrCode.contains('EXPIRED')) throw Exception('EXPIRED_QR');
      if (qrCode.contains('DUPLICATE')) throw Exception('DUPLICATE_QR');
      return {
        'photoId': DateTime.now().millisecondsSinceEpoch,
        'imageUrl': 'https://picsum.photos/seed/qr${DateTime.now().millisecondsSinceEpoch}/800/1066',
        'takenAt': DateTime.now().toIso8601String(),
        'location': '홍대 포토그레이',
        'brand': '인생네컷',
        'status': 'DRAFT',
      };
    }

    final uri = _endpoint('/api/photos/qr-import');
    final request = http.Request('POST', uri);
    request.headers['Authorization'] = 'Bearer ${AuthService.accessToken ?? ''}';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'qrCode': qrCode});

    final response = await http.Response.fromStream(await request.send());
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 400) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final error = body['error'] as String?;
      if (error == 'INVALID_QR') {
        throw Exception(body['message'] ?? '유효하지 않은 QR 코드입니다.');
      }
      throw Exception(body['message'] ?? '잘못된 요청입니다.');
    }
    if (response.statusCode == 404) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final error = body['error'] as String?;
      if (error == 'EXPIRED_QR') {
        throw Exception(body['message'] ?? '해당 QR 코드는 만료되었습니다.');
      }
      throw Exception(body['message'] ?? '해당 QR 코드를 찾을 수 없습니다.');
    }
    if (response.statusCode == 409) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final error = body['error'] as String?;
      if (error == 'DUPLICATE_QR') {
        throw Exception(body['message'] ?? '이미 업로드된 QR 코드입니다.');
      }
      throw Exception(body['message'] ?? '이미 업로드된 QR 코드입니다.');
    }
    if (response.statusCode == 502) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final error = body['error'] as String?;
      if (error == 'QR_PROVIDER_ERROR') {
        throw Exception(body['message'] ?? 'QR 제공 서버에서 사진을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.');
      }
      throw Exception(body['message'] ?? 'QR 제공 서버 오류');
    }
    if (response.statusCode == 401) {
      throw Exception('인증이 필요합니다.');
    }
    throw Exception('QR 임시 등록 실패 (${response.statusCode})');
  }

  /// POST /api/photos - QR 사진 업로드 (multipart/form-data)
  /// API 명세서: qrCode와 image 파일을 함께 전송
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
      if (!await imageFile.exists()) {
        throw Exception('IMAGE_REQUIRED');
      }
      if (qrCode.trim().isEmpty) throw Exception('INVALID_QR');
      if (qrCode.contains('EXPIRED')) throw Exception('EXPIRED_QR');
      if (qrCode.contains('DUPLICATE')) throw Exception('DUPLICATE_QR');
      return {
        'photoId': DateTime.now().millisecondsSinceEpoch,
        'imageUrl': imageFile.path,
        'takenAt': takenAtIso,
        'location': location,
        'brand': brand,
        'tagList': tagList ?? [],
        'friendList': friendIdList?.map((id) => {'userId': id, 'nickname': '친구$id'}).toList() ?? [],
        'memo': memo ?? '',
      };
    }

    final uri = _endpoint('/api/photos');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${AuthService.accessToken ?? ''}';

    // API 명세서: qrCode, image, takenAt, location, brand는 필수
    request.fields['qrCode'] = qrCode;
    request.fields['takenAt'] = takenAtIso;
    request.fields['location'] = location;
    request.fields['brand'] = brand;
    
    // 이미지 파일 필수
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );
    
    // 선택 필드
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
    // ignore: avoid_print
    print('[UPLOAD(QR)][status]=${response.statusCode}');
    // ignore: avoid_print
    print('[UPLOAD(QR)][raw]=${response.body}');

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 400) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final error = body['error'] as String?;
      final message = body['message'] as String?;
      if (error == 'IMAGE_REQUIRED') {
        throw Exception(message ?? '사진 파일은 필수입니다.');
      }
      if (error == 'INVALID_DATE_FORMAT') {
        throw Exception(message ?? '촬영 날짜 형식이 잘못되었습니다. ISO 8601 형식을 사용해주세요.');
      }
      if (error == 'INVALID_QR') {
        throw Exception(message ?? '유효하지 않은 QR 코드입니다.');
      }
      throw Exception(message ?? '잘못된 요청입니다.');
    }
    if (response.statusCode == 404) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final error = body['error'] as String?;
      if (error == 'EXPIRED_QR') {
        throw Exception(body['message'] ?? '해당 QR 코드는 만료되었습니다.');
      }
      throw Exception(body['message'] ?? '해당 QR 코드를 찾을 수 없습니다.');
    }
    if (response.statusCode == 409) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final error = body['error'] as String?;
      if (error == 'DUPLICATE_QR') {
        throw Exception(body['message'] ?? '이미 업로드된 QR 코드입니다.');
      }
      throw Exception(body['message'] ?? '이미 업로드된 QR 코드입니다.');
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
