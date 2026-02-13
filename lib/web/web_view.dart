import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_rounded_button.dart';

class WebUrls {
  static const String termsUrl = 'https://d1bcqxc59qdqw5.cloudfront.net/terms/';
  static const String privacyUrl =
      'https://d1bcqxc59qdqw5.cloudfront.net/privacy/';
  static const String marketingUrl =
      'https://d1bcqxc59qdqw5.cloudfront.net/marketing/';
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({
    super.key,
    required this.title,
    required this.url,
    this.showRevokeButton = false,
    this.onRevokeTap,
  });

  final String title;
  final String url;
  final bool showRevokeButton;
  final VoidCallback? onRevokeTap;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
          SafeArea(
            bottom: false,
            child: CommonNavigationView(
              left: const Icon(
                PhosphorIconsRegular.caretLeft,
                size: 24,
                color: Colors.black,
              ),
              onLeftTap: () => Navigator.of(context).maybePop(),
              title: widget.title,
            ),
          ),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          if (widget.showRevokeButton)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: CommonRoundedButton(
                  title: '동의 철회하기',
                  onTap: widget.onRevokeTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
