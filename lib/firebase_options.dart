import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBWk0mcUtIVFPo7Vk9MYrIhfwmWQ6pTmpU',
    appId: '1:610915465334:web:416c51e9ec2698aca84757',
    messagingSenderId: '610915465334',
    projectId: 'stash-3dd4e',
    authDomain: 'stash-3dd4e.firebaseapp.com',
    storageBucket: 'stash-3dd4e.firebasestorage.app',
    measurementId: 'G-F6HH1SGKKJ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBWk0mcUtIVFPo7Vk9MYrIhfwmWQ6pTmpU',
    appId: '1:610915465334:android:0583f2a20f729bc7a84757',
    messagingSenderId: '610915465334',
    projectId: 'stash-3dd4e',
    storageBucket: 'stash-3dd4e.firebasestorage.app',
  );
}
