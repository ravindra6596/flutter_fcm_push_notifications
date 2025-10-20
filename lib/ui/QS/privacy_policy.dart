import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrivacyPolicy extends StatefulWidget {
  const PrivacyPolicy({super.key});

  @override
  State<PrivacyPolicy> createState() => _PrivacyPolicyState();
}

class _PrivacyPolicyState extends State<PrivacyPolicy> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
    ..setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) => CircularProgressIndicator(),
        onProgress: (url) => CircularProgressIndicator(),
      )
    )
      ..loadRequest(Uri.parse('https://unicornwings.vercel.app/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Privacy Policy")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
