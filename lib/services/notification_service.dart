import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Central push-notification (FCM) manager for STASH.
///
/// Responsibilities:
///  • Ask the OS for notification permission (Android 13+ shows a dialog).
///  • Register the device's FCM token on the signed-in user's document so the
///    backend can target them (`users/{uid}.fcmTokens`).
///  • Keep that token fresh (refresh + on every login) and remove it on logout.
///  • Show foreground messages as a lightweight in-app banner (the OS shows
///    background / terminated notifications automatically).
///  • Provide navigator + messenger keys so it can surface UI from anywhere.
///
/// Everything is best-effort and wrapped in try/catch: a messaging failure must
/// never crash the app or block startup.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Wire these into MaterialApp so we can show banners / navigate on tap.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _initialized = false;

  /// Call once at startup, after Firebase is ready.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Ask for permission. On Android 13+ this triggers the POST_NOTIFICATIONS
    // system dialog; on older Android it is a no-op that returns authorized.
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {}

    // Foreground messages -> in-app banner (FCM does NOT show a system
    // notification while the app is in the foreground).
    FirebaseMessaging.onMessage.listen(_showInApp);

    // User tapped a notification that opened the app from the background.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // App launched from terminated by tapping a notification.
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleTap(initial);
    } catch (_) {}

    // Keep the stored token in sync when the OS rotates it.
    _messaging.onTokenRefresh.listen(_saveToken);

    // Save the token whenever a user signs in.
    _auth.authStateChanges().listen((user) {
      if (user != null) syncToken();
    });

    // If someone is already signed in at launch, register now.
    if (_auth.currentUser != null) await syncToken();
  }

  /// Fetches the current device token and stores it on the user document.
  Future<void> syncToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (_) {}
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).set({
        // arrayUnion so multiple devices per user are supported.
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmToken': token, // convenience: latest token
        'fcmPlatform': Platform.isIOS ? 'ios' : 'android',
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Removes this device's token. Call this right BEFORE signing out so the
  /// user stops receiving pushes for the account on this device.
  Future<void> removeCurrentToken() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _db.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Enable or disable push delivery for this device. Disabling removes this
  /// device's token (so the OS/backend stops delivering to it); enabling
  /// re-registers the token. The user's preference itself is persisted by
  /// SettingsService and also enforced server-side.
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await syncToken();
    } else {
      await removeCurrentToken();
    }
  }

  // ---- UI helpers ----

  void _showInApp(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final title = n.title ?? '';
    final body = n.body ?? '';
    if (title.isEmpty && body.isEmpty) return;

    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              if (body.isNotEmpty) Text(body),
            ],
          ),
        ),
      );
  }

  /// Hook for deep-linking. `message.data['type']` can be used to route to a
  /// specific screen (e.g. 'transaction' -> history, 'budget_alert' -> budget).
  /// Left intentionally light so it never fails; extend as routes are added.
  void _handleTap(RemoteMessage message) {
    // Example (enable once named routes exist):
    // final type = message.data['type'];
    // if (type == 'budget_alert') {
    //   navigatorKey.currentState?.pushNamed('/budget');
    // }
  }
}
