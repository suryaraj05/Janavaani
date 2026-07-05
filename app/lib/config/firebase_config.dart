import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for project `mpconnect-67f6c`.
///
/// **Web demo:** [web] is fully configured. Local app: http://localhost:5050
/// Backend API: http://localhost:8092 (must match `INTAKE_PORT` in `.env`).
///
/// **Mobile:** [android] and [ios] currently reuse the web appId as a placeholder.
/// For real device builds, run `flutterfire configure` or register native apps in
/// Firebase Console and add `google-services.json` / `GoogleService-Info.plist`.
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCrIXsjzG3UowV0UhaKEWvq00ih5n5s1Yk',
    appId: '1:90289308138:web:7846804f7ed77dc3dbb293',
    messagingSenderId: '90289308138',
    projectId: 'mpconnect-67f6c',
    authDomain: 'mpconnect-67f6c.firebaseapp.com',
    storageBucket: 'mpconnect-67f6c.firebasestorage.app',
    measurementId: 'G-8901XBQ1LQ',
  );

  /// Register an Android app in Firebase Console, then paste its appId here.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCrIXsjzG3UowV0UhaKEWvq00ih5n5s1Yk',
    appId: '1:90289308138:web:7846804f7ed77dc3dbb293',
    messagingSenderId: '90289308138',
    projectId: 'mpconnect-67f6c',
    authDomain: 'mpconnect-67f6c.firebaseapp.com',
    storageBucket: 'mpconnect-67f6c.firebasestorage.app',
  );

  /// Register an iOS app in Firebase Console, then paste its appId here.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCrIXsjzG3UowV0UhaKEWvq00ih5n5s1Yk',
    appId: '1:90289308138:web:7846804f7ed77dc3dbb293',
    messagingSenderId: '90289308138',
    projectId: 'mpconnect-67f6c',
    authDomain: 'mpconnect-67f6c.firebaseapp.com',
    storageBucket: 'mpconnect-67f6c.firebasestorage.app',
    iosBundleId: 'com.surya.campusconnect',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        return web;
    }
  }
}
