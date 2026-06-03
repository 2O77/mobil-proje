import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';

final sessionStreamProvider = StreamProvider<Session?>((ref) {
  final controller = StreamController<Session?>();
  StreamSubscription<User?>? authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? docSub;

  void cancelDoc() {
    docSub?.cancel();
    docSub = null;
  }

  void attachDocListener(User user) {
    cancelDoc();
    docSub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen(
      (doc) {
        final profile =
            doc.exists && doc.data() != null ? UserProfile.fromDoc(user.uid, doc.data()!) : null;
        controller.add(Session(user: user, profile: profile));
      },
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('sessionStream Firestore: $e');
        }
        controller.addError(e, st);
      },
    );
  }

  authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user == null) {
      cancelDoc();
      controller.add(null);
    } else {
      attachDocListener(user);
    }
  });

  ref.onDispose(() async {
    await authSub?.cancel();
    cancelDoc();
    await controller.close();
  });

  return controller.stream;
});

final routerRefreshProvider = Provider<RouterRefresh>((ref) {
  final notifier = RouterRefresh();
  ref.listen(
    sessionStreamProvider,
    (previous, next) => notifier.ping(),
    fireImmediately: true,
  );
  ref.onDispose(notifier.dispose);
  return notifier;
});

class RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
