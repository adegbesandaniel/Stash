import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download of [bytes] as [filename] on Flutter web.
///
/// Wraps the bytes in a Blob, creates a temporary object URL, clicks a hidden
/// anchor to start the download, then revokes the URL. Returns `true` on
/// success so the caller can show a confirmation.
Future<bool> downloadPdf(List<int> bytes, String filename) async {
  final blob = html.Blob(<dynamic>[Uint8List.fromList(bytes)], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
