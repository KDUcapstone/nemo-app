import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// QR 임시 등록된 사진의 photoId를 로컬 스토리지에 저장/관리하는 유틸
/// - 앱이 종료되어도 임시저장된 사진을 추적 가능
/// - 앱 시작 시 저장된 photoId들을 삭제하여 정리
class TempPhotoStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyPrefix = 'temp_photo_';

  /// 임시저장된 photoId 저장
  static Future<void> saveTempPhotoId(int photoId) async {
    try {
      final key = '$_keyPrefix$photoId';
      await _storage.write(
        key: key,
        value: DateTime.now().toIso8601String(), // 저장 시각 기록 (나중에 정리할 때 참고)
      );
      print('💾 [TempPhotoStorage] 임시저장 photoId 저장: $photoId');
    } catch (e) {
      print('⚠️ [TempPhotoStorage] 임시저장 photoId 저장 실패: $e');
    }
  }

  /// 저장된 모든 임시저장 photoId 목록 조회
  static Future<List<int>> getAllTempPhotoIds() async {
    try {
      // flutter_secure_storage는 모든 키를 조회하는 API가 없으므로
      // 대신 별도의 키로 목록을 저장하는 방식 사용
      final listKey = '${_keyPrefix}list';
      final listJson = await _storage.read(key: listKey);
      
      if (listJson == null || listJson.isEmpty) {
        return [];
      }

      final List<dynamic> photoIds = jsonDecode(listJson);
      return photoIds.map((id) => id as int).toList();
    } catch (e) {
      print('⚠️ [TempPhotoStorage] 임시저장 photoId 목록 조회 실패: $e');
      return [];
    }
  }

  /// 임시저장 photoId를 목록에 추가
  static Future<void> addTempPhotoId(int photoId) async {
    try {
      final existingIds = await getAllTempPhotoIds();
      if (existingIds.contains(photoId)) {
        return; // 이미 존재하면 추가하지 않음
      }

      existingIds.add(photoId);
      final listKey = '${_keyPrefix}list';
      await _storage.write(
        key: listKey,
        value: jsonEncode(existingIds),
      );
      print('💾 [TempPhotoStorage] 임시저장 photoId 추가: $photoId (총 ${existingIds.length}개)');
    } catch (e) {
      print('⚠️ [TempPhotoStorage] 임시저장 photoId 추가 실패: $e');
    }
  }

  /// 임시저장 photoId 제거 (추가 완료 시)
  static Future<void> removeTempPhotoId(int photoId) async {
    try {
      final existingIds = await getAllTempPhotoIds();
      if (!existingIds.contains(photoId)) {
        return; // 존재하지 않으면 무시
      }

      existingIds.remove(photoId);
      final listKey = '${_keyPrefix}list';
      
      if (existingIds.isEmpty) {
        // 목록이 비면 키 삭제
        await _storage.delete(key: listKey);
      } else {
        await _storage.write(
          key: listKey,
          value: jsonEncode(existingIds),
        );
      }

      // 개별 키도 삭제 (있다면)
      final key = '$_keyPrefix$photoId';
      await _storage.delete(key: key);

      print('🗑️ [TempPhotoStorage] 임시저장 photoId 제거: $photoId (남은 개수: ${existingIds.length})');
    } catch (e) {
      print('⚠️ [TempPhotoStorage] 임시저장 photoId 제거 실패: $e');
    }
  }

  /// 모든 임시저장 photoId 제거 (앱 시작 시 정리용)
  static Future<void> clearAllTempPhotoIds() async {
    try {
      final photoIds = await getAllTempPhotoIds();
      
      // 모든 개별 키 삭제
      for (final photoId in photoIds) {
        final key = '$_keyPrefix$photoId';
        await _storage.delete(key: key);
      }

      // 목록 키 삭제
      final listKey = '${_keyPrefix}list';
      await _storage.delete(key: listKey);

      print('🧹 [TempPhotoStorage] 모든 임시저장 photoId 제거 완료 (${photoIds.length}개)');
    } catch (e) {
      print('⚠️ [TempPhotoStorage] 임시저장 photoId 전체 제거 실패: $e');
    }
  }
}

