import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:frontend/services/auth_service.dart';

class TurnstileWidget extends StatefulWidget {
  final String siteKey;
  final Function(String token) onSuccess;
  final Function(String? error) onError;

  const TurnstileWidget({
    super.key,
    required this.siteKey,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<TurnstileWidget> createState() => _TurnstileWidgetState();
}

class _TurnstileWidgetState extends State<TurnstileWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 백엔드 URL 구성
    String turnstileUrl;
    final baseUrl = AuthService.baseUrl;

    // Android 에뮬레이터의 경우 localhost를 10.0.2.2로 변환
    if (Platform.isAndroid && baseUrl.contains('localhost')) {
      turnstileUrl = baseUrl.replaceAll('localhost', '10.0.2.2');
    } else {
      turnstileUrl = baseUrl;
    }

    // baseUrl 끝의 슬래시 처리
    if (!turnstileUrl.endsWith('/')) {
      turnstileUrl = '$turnstileUrl/';
    }

    // Turnstile 엔드포인트 URL 구성 (siteKey를 쿼리 파라미터로 전달)
    final uri = Uri.parse(
      '${turnstileUrl}api/auth/turnstile',
    ).replace(queryParameters: {'sitekey': widget.siteKey});

    print('🔍 [TurnstileWidget] Turnstile URL: $uri');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            print('🔴 [TurnstileWidget] WebView 오류: ${error.description}');
            widget.onError('캡챠를 불러오는 중 오류가 발생했습니다: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'TurnstileChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final data = message.message;
          if (data.startsWith('SUCCESS:')) {
            final token = data.substring(8);
            widget.onSuccess(token);
          } else if (data.startsWith('ERROR:')) {
            final error = data.substring(6);
            widget.onError(error);
          }
        },
      )
      ..loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _controller),
    );
  }
}
