import 'dart:io' show Platform;

class Env {
  /// 자동으로 플랫폼에 따라 base url 결정
  static String get apiBaseUrl {
    // 1) 릴리즈 빌드는 실서버 자동 사용
    const String prodUrl = 'https://api.nemo.app';

    // 2) 디버그 모드인지 체크
    const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;

    if (!isDebug) {
      // 릴리즈이면 무조건 prod 서버
      return prodUrl;
    }

    // 3) 디버그 환경 — 여기서 플랫폼 자동 분기

    if (Platform.isAndroid) {
      // 안드로이드 에뮬레이터
      return 'http://10.0.2.2:8080';

      // 실기기 → 10.0.2.2는 안 됨, PC 로컬 접속 불가
      // adb reverse 있는지 체크는 flutter가 못함 → 대신 아래로 fallback
    }

    if (Platform.isIOS) {
      // iOS 에뮬레이터는 localhost 사용 가능
      return 'http://localhost:8080';
    }

    // 기타 (Windows/Chrome/macOS)
    return 'http://localhost:8080';
  }
}
