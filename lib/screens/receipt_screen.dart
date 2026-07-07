import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../utils/pdf_download.dart';

/// A branded STASH receipt for a single transaction. Reachable from the
/// success popup right after a transaction completes and from Transaction
/// History (tap any row). Constructor is unchanged so existing callers keep
/// working.
class ReceiptScreen extends StatelessWidget {
  final String type; // 'income' | 'expense' | 'lock'
  final String category;
  final double amount;
  final String note;
  final DateTime date;
  final String reference;
  final String status;

  const ReceiptScreen({
    super.key,
    required this.type,
    required this.category,
    required this.amount,
    required this.note,
    required this.date,
    required this.reference,
    this.status = 'Successful',
  });

  bool get _isIncome => type == 'income';
  bool get _isTransfer => category.toLowerCase().contains('transfer');

  String get _subtitle {
    if (_isTransfer) return 'Transfer successful';
    if (_isIncome) return 'Money received';
    return 'Payment successful';
  }

  static String formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day} ${months[d.month - 1]} ${d.year}, '
        '${two(h)}:${two(d.minute)} $ampm';
  }

  String get _receiptText {
    final buffer = StringBuffer()
      ..writeln('STASH - Transaction Receipt')
      ..writeln('--------------------------------')
      ..writeln('Status     : $status')
      ..writeln('Type       : ${_isIncome ? 'Money In' : 'Money Out'}')
      ..writeln('Category   : $category')
      ..writeln('Amount     : ${Money.naira(amount)}')
      ..writeln('Fee        : ${Money.naira(0)}')
      ..writeln('Date       : ${formatDateTime(date)}')
      ..writeln('Reference  : $reference');
    if (note.trim().isNotEmpty) {
      buffer.writeln('Note       : ${note.trim()}');
    }
    buffer
      ..writeln('--------------------------------')
      ..writeln('Thank you for using STASH');
    return buffer.toString();
  }

  void _share(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _receiptText));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Receipt copied - paste it anywhere to share.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Builds a branded PDF of this receipt and opens the system share / print
  /// sheet (save to Files, send via WhatsApp/email, print, etc.).
  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final doc = pw.Document();
      const accent = PdfColor.fromInt(0xFFC8FF4D);
      const dark = PdfColor.fromInt(0xFF0A0A0C);

      pw.Widget line(String l, String v) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(l,
                    style: const pw.TextStyle(
                        color: PdfColors.grey700, fontSize: 11)),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Text(v,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          );

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) {
            return pw.Center(
              child: pw.Container(
                width: 330,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(16),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: const pw.BoxDecoration(
                        color: dark,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(10)),
                      ),
                      child: pw.Center(
                        child: pw.Text('STASH',
                            style: pw.TextStyle(
                                color: accent,
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 2)),
                      ),
                    ),
                    pw.SizedBox(height: 18),
                    pw.Center(
                      child: pw.Text(Money.naira(amount),
                          style: pw.TextStyle(
                              fontSize: 26, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Center(
                      child: pw.Text(_subtitle,
                          style: pw.TextStyle(
                              color: PdfColors.green700,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(height: 18),
                    pw.Divider(color: PdfColors.grey300),
                    if (_isTransfer)
                      line('Type', 'Transfer')
                    else
                      line('Category', category),
                    if (note.trim().isNotEmpty)
                      line('Description', note.trim()),
                    line('Amount', Money.naira(amount)),
                    line('Fee', Money.naira(0)),
                    line('Date', formatDateTime(date)),
                    line('Reference', reference),
                    line('Status', status),
                    pw.Divider(color: PdfColors.grey300),
                    pw.SizedBox(height: 10),
                    pw.Center(
                      child: pw.Text('Thank you for using STASH',
                          style: const pw.TextStyle(
                              color: PdfColors.grey600, fontSize: 10)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final bytes = await doc.save();
      final downloaded =
          await downloadPdf(bytes, 'STASH_Receipt_$reference.pdf');
      if (!context.mounted) return;
      if (downloaded) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Receipt PDF downloaded.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
      } else {
        // PDF download is wired for the web build; on other platforms fall
        // back to copying the text receipt so the button still helps.
        _share(context);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not generate PDF. Try again.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 26),
              Center(child: _statusBadge()),
              const SizedBox(height: 18),
              Center(
                child: Text(Money.naira(amount),
                    style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                        letterSpacing: -1)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(_subtitle,
                    style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 28),
              _ticket(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _shareBar(context),
    );
  }

  // ---- Header (X close) ----
  Widget _header(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.close_rounded, size: 20, color: AppColors.text),
          ),
        ),
        const SizedBox(width: 14),
        Text('Receipt',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
      ],
    );
  }

  Widget _statusBadge() {
    return Container(
      width: 92,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(40),
      ),
      child: const Icon(Icons.check_rounded, color: AppColors.success, size: 32),
    );
  }

  // ---- Ticket card ----
  Widget _ticket() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (_isTransfer) ...[
            _row('Type', 'Transfer'),
          ] else
            _row('Category', category),
          if (note.trim().isNotEmpty) _row('Description', note.trim()),
          _perforation(),
          _row('Amount', Money.naira(amount)),
          _row('Fee', Money.naira(0)),
          _row('Date', formatDateTime(date)),
          _row('Reference', reference),
        ],
      ),
    );
  }

  Widget _perforation() {
    // NOTE: Flutter forbids negative margins (Container asserts
    // margin.isNonNegative), so we can't use EdgeInsets(horizontal: -22) to make
    // the notches spill past the card's padding. Instead we measure the padded
    // content width and use an OverflowBox to render the row 22px wider on each
    // side, keeping the exact same ticket-notch look without crashing.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fullWidth = constraints.maxWidth + 44; // 22px past each edge
          return OverflowBox(
            minWidth: fullWidth,
            maxWidth: fullWidth,
            child: Row(
              children: [
                Transform.translate(
                  offset: const Offset(-11, 0),
                  child: _notch(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _DashedLine(),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(11, 0),
                  child: _notch(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _notch() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ).copyWith(color: AppColors.background),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: valueColor ?? AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ---- Action buttons (Copy + Download PDF) ----
  Widget _shareBar(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                onPressed: () => _share(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy_rounded, size: 18, color: AppColors.text),
                    const SizedBox(width: 8),
                    Text('Copy',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                onPressed: () => _downloadPdf(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.picture_as_pdf_rounded,
                        size: 18, color: Color(0xFF0A0A0C)),
                    SizedBox(width: 8),
                    Text('Download PDF',
                        style: TextStyle(
                            color: Color(0xFF0A0A0C),
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal dashed line that fills the available width.
class _DashedLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 5.0;
        final count =
            (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count < 0 ? 0 : count,
            (_) => Container(
              width: dashWidth,
              height: 1.6,
              color: AppColors.border,
            ),
          ),
        );
      },
    );
  }
}
