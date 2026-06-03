import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/therapist_listing.dart';

final therapistsDirectoryProvider = FutureProvider<List<TherapistListing>>((ref) async {
  final db = FirebaseFirestore.instance;

  try {
    final snap = await db.collection('therapists').orderBy('sortOrder').get().timeout(
      const Duration(seconds: 8),
    );
    return snap.docs.map((d) => TherapistListing.fromDoc(d.id, d.data())).toList();
  } catch (_) {
    return const <TherapistListing>[];
  }
});
