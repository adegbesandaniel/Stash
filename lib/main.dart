import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

/// Handles FCM messages that arrive while the app is in the background or
/// terminated. Must be a top-level function annotated with @pragma so it
/// survives tree-shaking in release builds. For "notification" payloads the OS
/// shows the alert automatically, so this is currently a placeholder for future
/// data-only handling.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

void main() {
  // Show a readable error on screen instead of a silent crash / blank screen,
  // especially in release builds running on a physical device.
  ErrorWidget.builder = (FlutterErrorDetails details) =>
      _StartupErrorView(message: details.exceptionAsString());

  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    String? startupError;

    // IMPORTANT: On Android, Firebase auto-initializes the default app natively
    // from google-services.json *before* Dart runs. Calling initializeApp again
    // with options can throw [core/duplicate-app] and crash on launch.
    // So only initialize if no app exists yet.
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } on FirebaseException catch (e, s) {
      // On Android, the native layer can auto-initialize the default app from
      // google-services.json BEFORE Dart runs, so a second initializeApp call
      // throws [core/duplicate-app]. That simply means Firebase is already
      // ready, so we ignore it and only surface genuine init failures.
      if (e.code != 'duplicate-app') {
        startupError = 'Firebase init failed:\n$e\n\n$s';
      }
    } catch (e, s) {
      startupError = 'Firebase init failed:\n$e\n\n$s';
    }

    // 🔔 Push notifications (FCM). Wrapped so a messaging failure can never
    // block startup — the app must still open even if notifications fail.
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await NotificationService.instance.init();
    } catch (_) {}

    // Restore the saved theme if a user is already signed in.
    try {
      ThemeController.isDark.value = await SettingsService().loadDarkMode();
    } catch (_) {}

    runApp(StashApp(startupError: startupError));
  }, (error, stack) {
    // Last-resort handler: still show something instead of a hard crash.
    runApp(StashApp(startupError: '$error\n\n$stack'));
  });
}

class StashApp extends StatelessWidget {
  final String? startupError;
  const StashApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.isDark,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'STASH',
          navigatorKey: NotificationService.instance.navigatorKey,
          scaffoldMessengerKey: NotificationService.instance.messengerKey,
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: startupError == null
              ? const SplashScreen()
              : _StartupErrorView(message: startupError!),
        );
      },
    );
  }
}

/// Full-screen error view used for startup failures and as the global
/// ErrorWidget. Kept dependency-free so it renders even if init failed.
class _StartupErrorView extends StatelessWidget {
  final String message;
  const _StartupErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF0E0F12),
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Startup error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please screenshot this whole message so it can be fixed:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
