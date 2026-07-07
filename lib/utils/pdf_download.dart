// Cross-platform PDF output for STASH receipts.
//
// The `printing` plugin was removed because its Android resources require an
// API 31+ SDK (android:attr/lStar) that the cloud builder can't resolve,
// which broke `assembleRelease` at `:printing:verifyReleaseResources`.
//
// Instead we generate the PDF bytes with the pure-Dart `pdf` package and hand
// them off per platform via a conditional import:
//   - Web    -> trigger a real browser download (dart:html).
//   - Others -> no-op that returns false, so callers can fall back gracefully
//               (e.g. copy the text receipt).
export 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart';
