/// Fallback used on platforms without `dart:html` (Android / iOS / desktop).
///
/// Returns `false` so the caller can fall back gracefully — e.g. copy the
/// text receipt to the clipboard instead of downloading a file.
Future<bool> downloadPdf(List<int> bytes, String filename) async => false;
