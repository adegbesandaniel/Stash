import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// CLIENT-SIDE Paystack integration (no backend required for now).
///
/// - [publicKey]  → used for inline checkout (wallet funding). SAFE to embed.
/// - [secretKey]  → used ONLY for account-name resolution on transfers.
///   ⚠️ The secret key is SENSITIVE. Embedding it is acceptable for TEST mode
///   so you can build fast, but BEFORE GOING LIVE move every secret-key call to
///   a secure backend — anyone who decompiles the APK can read an embedded key.
///
/// NOTE: This uses Dart's built-in HttpClient (dart:io), so the `http` package
/// is NOT required. Works on Android out of the box.
class PaymentService {
  /// 👉 Your Paystack TEST public key (starts with pk_test_). Safe to embed.
  static const String publicKey = 'pk_test_REPLACE_WITH_YOUR_PUBLIC_KEY';

  /// 👉 Your Paystack TEST secret key (starts with sk_test_).
  /// NEVER share this key, and NEVER put a LIVE secret key here.
  static const String secretKey = 'sk_test_REPLACE_WITH_YOUR_SECRET_KEY';

  /// Creates a unique reference for each funding attempt.
  /// Paystack only allows letters, numbers and - . = in references,
  /// so we use hyphens (never underscores).
  String generateReference() {
    final rand = Random();
    final tail =
        List.generate(10, (_) => rand.nextInt(36).toRadixString(36)).join();
    return 'stash-${DateTime.now().millisecondsSinceEpoch}-$tail';
  }

  /// Resolves a bank account number to the real account name via Paystack.
  /// Returns (name: "JOHN DOE", error: null) on success,
  /// otherwise (name: null, error: "<reason>").
  Future<({String? name, String? error})> resolveAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    if (secretKey.isEmpty || secretKey.contains('REPLACE')) {
      return (
        name: null,
        error: 'Add your Paystack secret key in PaymentService.secretKey.',
      );
    }

    final uri = Uri.parse(
      'https://api.paystack.co/bank/resolve'
      '?account_number=$accountNumber&bank_code=$bankCode',
    );

    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);

      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $secretKey');

      final response =
          await request.close().timeout(const Duration(seconds: 20));
      final responseBody = await response.transform(utf8.decoder).join();

      final body = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['status'] == true) {
        final name = (body['data']?['account_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          return (name: name, error: null);
        }
        return (name: null, error: 'Account name not found.');
      }

      return (
        name: null,
        error: (body['message'] as String?) ?? 'Could not verify this account.',
      );
    } catch (_) {
      return (name: null, error: 'Network error while verifying account.');
    } finally {
      client?.close();
    }
  }
}
