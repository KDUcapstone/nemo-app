class AppConstants {
  // 백엔드 연동 전까지 모킹 사용 여부
  // const 대신 일반 변수로 변경하여 Hot Reload 시 반영되도록 함
  static bool useMockApi = false;

  // 모킹 시 네트워크 지연 흉내(ms)
  static const int simulatedNetworkDelayMs = 500;

  // 홈 화면 네이버 지도 표시 토글(인증 문제 시 크래시 회피용)
  static const bool enableHomeMap = true;
}
