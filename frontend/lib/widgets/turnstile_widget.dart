import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

    final htmlContent =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
  <style>
    body {
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      background: transparent;
    }
    #turnstile-widget {
      display: flex;
      justify-content: center;
      align-items: center;
    }
  </style>
</head>
<body>
  <div id="turnstile-widget"></div>
  <script>
    function initTurnstile() {
      if (window.turnstile) {
        window.turnstile.render('#turnstile-widget', {
          sitekey: '${widget.siteKey}',
          callback: function(token) {
            TurnstileChannel.postMessage('SUCCESS:' + token);
          },
          'error-callback': function() {
            TurnstileChannel.postMessage('ERROR:Turnstile verification failed');
          },
          'expired-callback': function() {
            TurnstileChannel.postMessage('ERROR:Turnstile token expired');
          }
        });
      } else {
        // 스크립트가 아직 로드되지 않음, 잠시 후 재시도
        setTimeout(initTurnstile, 100);
      }
    }
    
    // DOM이 준비되면 시도
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', initTurnstile);
    } else {
      // 이미 로드됨
      initTurnstile();
    }
  </script>
</body>
</html>
    ''';

    // base64로 인코딩하여 data URI 생성
    final base64Content = base64Encode(utf8.encode(htmlContent));
    final dataUri = 'data:text/html;charset=utf-8;base64,$base64Content';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
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
      ..loadRequest(Uri.parse(dataUri));
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
