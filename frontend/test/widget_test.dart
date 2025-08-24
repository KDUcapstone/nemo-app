// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('로그인 화면 스모크 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(const NemoApp());

    // 앱이 로그인 화면을 띄우고 핵심 텍스트/버튼을 보여주는지 확인
    expect(find.text('네컷 모아'), findsOneWidget);
    expect(find.text('이메일로 시작하기'), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('Google로 시작하기'), findsOneWidget);
  });
}
