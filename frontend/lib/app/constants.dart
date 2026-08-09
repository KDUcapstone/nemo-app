class AppConstants {
  // 기본은 실제 백엔드이며 테스트/데모에서만 --dart-define으로 mock을 켭니다.
  static bool useMockApi = const bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );

  // 모킹 시 네트워크 지연 흉내(ms)
  static const int simulatedNetworkDelayMs = 500;

  // 홈 화면 네이버 지도 표시 토글(인증 문제 시 크래시 회피용)
  static const bool enableHomeMap = true;
}
