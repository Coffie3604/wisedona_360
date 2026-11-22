import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase project configuration for the `wisedona-360` project.
///
/// The web values come from the Firebase console snippet. Native platforms
/// (Android/iOS) need their own app registrations; until those are added the
/// app falls back to the web options, which is enough for Auth + Firestore on
/// Android because both services are keyed by projectId/apiKey.
///
/// To generate real per-platform values run:
///   flutterfire configure --project=wisedona-360
/// which overwrites this file.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const String projectId = 'wisedona-360';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA3s2kC_xqgPy90x-MdgWOUFLyRCTpkcN8',
    authDomain: 'wisedona-360.firebaseapp.com',
    projectId: 'wisedona-360',
    storageBucket: 'wisedona-360.firebasestorage.app',
    messagingSenderId: '419509950860',
    appId: '1:419509950860:web:15d3ac022cbbdefe639ea9',
  );

  // TODO(flutterfire): replace with the Android app registration.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA3s2kC_xqgPy90x-MdgWOUFLyRCTpkcN8',
    appId: '1:419509950860:android:15d3ac022cbbdefe639ea9',
    messagingSenderId: '419509950860',
    projectId: 'wisedona-360',
    storageBucket: 'wisedona-360.firebasestorage.app',
  );

  // TODO(flutterfire): replace with the iOS app registration.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA3s2kC_xqgPy90x-MdgWOUFLyRCTpkcN8',
    appId: '1:419509950860:ios:15d3ac022cbbdefe639ea9',
    messagingSenderId: '419509950860',
    projectId: 'wisedona-360',
    storageBucket: 'wisedona-360.firebasestorage.app',
    iosBundleId: 'com.wisedona.wisedona360',
  );
}
