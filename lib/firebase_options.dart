import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCqvtUPwjjffNt2Crfif2_FnujE1op9zRU',
    appId: '1:70931966066:web:ADD_WEB_APP_IN_FIREBASE_CONSOLE',
    messagingSenderId: '70931966066',
    projectId: 'auticare-c5c5a',
    authDomain: 'auticare-c5c5a.firebaseapp.com',
    storageBucket: 'auticare-c5c5a.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCqvtUPwjjffNt2Crfif2_FnujE1op9zRU',
    appId: '1:70931966066:android:ed35d4886c66c1b25b3aeb',
    messagingSenderId: '70931966066',
    projectId: 'auticare-c5c5a',
    storageBucket: 'auticare-c5c5a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCqvtUPwjjffNt2Crfif2_FnujE1op9zRU',
    appId: '1:70931966066:ios:ADD_IOS_APP_IN_FIREBASE_CONSOLE',
    messagingSenderId: '70931966066',
    projectId: 'auticare-c5c5a',
    storageBucket: 'auticare-c5c5a.firebasestorage.app',
    iosBundleId: 'com.auticare.auticare',
  );
}
