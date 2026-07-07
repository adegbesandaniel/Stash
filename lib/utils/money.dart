/// Professional Nigerian Naira formatting for STASH.
///
/// No external dependency required (avoids adding `intl`). Always format money
/// through this helper so currency styling stays consistent across the app.
class Money {
  Money._();

  static String _grouped(num value) {
    final bool negative = value < 0;
    final String digits = value.abs().toStringAsFixed(0);
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return '${negative ? '-' : ''}$out';
  }

  /// e.g. ₦125,600
  static String naira(num value) => '₦${_grouped(value)}';

  /// Compact form for tight UI, e.g. ₦1.3M / ₦250.0K
  static String compact(num value) {
    final bool negative = value < 0;
    final double v = value.abs().toDouble();
    String out;
    if (v >= 1e9) {
      out = '₦${(v / 1e9).toStringAsFixed(2)}B';
    } else if (v >= 1e6) {
      out = '₦${(v / 1e6).toStringAsFixed(2)}M';
    } else if (v >= 1e3) {
      out = '₦${(v / 1e3).toStringAsFixed(1)}K';
    } else {
      out = naira(v);
    }
    return negative ? '-$out' : out;
  }

  /// Masked balance for the hide/show feature.
  static const String hidden = '₦ • • • • •';
}
