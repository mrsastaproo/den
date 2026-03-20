import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQL0xDlsbGovQSTthjQ02BKWeiSsv7ucQ',
    appId: '1:1060749102477:android:ac04891eb66b9e116201c4',
    messagingSenderId: '1060749102477',
    projectId: 'den-music',
    storageBucket: 'den-music.appspot.com',
  );
}