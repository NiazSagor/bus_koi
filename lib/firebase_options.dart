// GENERATED PLACEHOLDER — replace by running `flutterfire configure` from
// the project root once a real Firebase project exists. That command
// overwrites this file with real values for every configured platform.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
    }
  }

  static const web = FirebaseOptions(
    apiKey: 'TODO-REPLACE-WITH-FLUTTERFIRE-CONFIGURE',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: 'TODO',
    databaseURL: 'https://TODO.firebaseio.com',
  );

  static const android = FirebaseOptions(
    apiKey: 'TODO-REPLACE-WITH-FLUTTERFIRE-CONFIGURE',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: 'TODO',
    databaseURL: 'https://TODO.firebaseio.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'TODO-REPLACE-WITH-FLUTTERFIRE-CONFIGURE',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: 'TODO',
    databaseURL: 'https://TODO.firebaseio.com',
    iosBundleId: 'com.example.busKoi',
  );
}
