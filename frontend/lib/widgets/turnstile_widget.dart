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
      ..loadRequest(
        Uri.dataFromString(
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
  </script>
</body>
</html>
          ''',
          mimeType: 'text/html',
        ),
      );
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

