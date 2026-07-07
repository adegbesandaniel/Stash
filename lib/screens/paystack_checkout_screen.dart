import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
// Platform switch: use the real WebView on mobile, a safe stub on web.
// On web, `dart.library.html` exists, so the web file is used and
// webview_flutter is never pulled into the web build.
import 'paystack_view_mobile.dart'
    if (dart.library.html) 'paystack_view_web.dart';

/// Opens Paystack Checkout. Pops the transaction `reference` (String) on
/// success, or `null` if the user cancels / closes the checkout.
class PaystackCheckoutScreen extends StatelessWidget {
  final String publicKey;
  final String email;
  final double amountNaira;
  final String reference;

  const PaystackCheckoutScreen({
    super.key,
    required this.publicKey,
    required this.email,
    required this.amountNaira,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: Text('Fund Wallet',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: PaystackView(
        publicKey: publicKey,
        email: email,
        amountNaira: amountNaira,
        reference: reference,
        onSuccess: (ref) => Navigator.of(context).pop(ref),
        onCancel: () => Navigator.of(context).pop(null),
      ),
    );
  }
}
