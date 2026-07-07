import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Web fallback. Paystack's in-app WebView only works on Android/iOS, so on the
/// FlutLab web preview we show a friendly notice instead. This keeps the whole
/// app compiling for web (no webview_flutter import here). Real payments run on
/// the Android build.
class PaystackView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_iphone_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Run on Android to pay',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text)),
            const SizedBox(height: 8),
            Text(
                'Paystack checkout uses an in-app browser that only works on the Android app, not the web preview.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.muted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 20),
            TextButton(
                onPressed: onCancel, child: const Text('Go back')),
          ],
        ),
      ),
    );
  }
}
