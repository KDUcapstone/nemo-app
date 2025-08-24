import 'package:flutter/material.dart';

// 앱의 모든 색상을 이곳에서 관리합니다.
// 이렇게 하면 디자인을 일관성 있게 유지하고, 나중에 색상 변경이 쉬워집니다.
class AppColors {
  // 이 클래스가 실수로 인스턴스화되는 것을 방지합니다.
  AppColors._();

  // ## 주요 색상 (Primary Colors) — 파스텔 하늘색 톤
  static const Color primary = Color(0xFF76BDF2); // 메인 액션 파스텔 블루
  static const Color secondary = Color(0xFFE7EEFC); // 아주 연한 하늘톤 배경 (하단바 배경)
  static const Color accent = Color(0xFF9AD7FF); // 포커스/포인트

  // 파스텔 스카이 그라디언트 팔레트
  static const Color skyLight = Color(0xFFEAF5FF);
  static const Color skySoft = Color(0xFFBDE0FE);
  static const Color skyMid = Color(0xFFAEDBFF);
  static const Color skyDeep = Color(0xFF90CAF9);

  // ## 텍스트 색상 (Text Colors)
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color textDisabled = Color(0xFFBDC3C7);

  // ## 배경 색상 (Background Colors)
  static const Color background = Color(0xFFF5F7FA);
  static const Color white = Colors.white;

  // ## 기타 UI 색상 (Miscellaneous Colors)
  static const Color divider = Color(0xFFEAECEF);
  static const Color disabled = Color(0xFFD3DCE6);
  static const Color error = Color(0xFFE74C3C);
}
