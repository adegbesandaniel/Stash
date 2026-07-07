import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

/// Mobile (Android/iOS) Paystack checkout, rendered in an in-app WebView.
/// This file is ONLY compiled on mobile — never on web (see the conditional
/// import in paystack_checkout_screen.dart), so webview_flutter never reaches
/// the web build.
class PaystackView extends StatefulWidget {
  final String publicKey;
  final String email;
  final double amountNaira;
  final String reference;
  final void Function(String reference) onSuccess;
  final VoidCallback onCancel;

  const PaystackView({
    super.key,
    required this.publicKey,
    required this.email,
    required this.amountNaira,
    required this.reference,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<PaystackView> createState() => _PaystackViewState();
}

class _PaystackViewState extends State<PaystackView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final kobo = (widget.amountNaira * 100).round();

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background:#F5F6FB;">
  <script src="https://js.paystack.co/v1/inline.js"></script>
  <script type="text/javascript">
    function payWithPaystack() {
      var handler = PaystackPop.setup({
        key: '${widget.publicKey}',
        email: '${widget.email}',
        amount: $kobo,
        currency: 'NGN',
        ref: '${widget.reference}',
        metadata: {
          custom_fields: [
            { display_name: "Purpose", variable_name: "purpose", value: "wallet_funding" }
          ]
        },
        callback: function(response) {
          window.location.href = 'https://stash.callback/success?reference=' + response.reference;
        },
        onClose: function() {
          window.location.href = 'https://stash.callback/cancel';
        }
      });
      handler.openIframe();
    }
    window.onload = payWithPaystack;
  </script>
</body>
</html>
''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('https://stash.callback/success')) {
              final ref = Uri.parse(url).queryParameters['reference'] ??
                  widget.reference;
              widget.onSuccess(ref);
              return NavigationDecision.prevent;
            }
            if (url.startsWith('https://stash.callback/cancel')) {
              widget.onCancel();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(html, baseUrl: 'https://stash.app');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
      ],
    );
  }
}
