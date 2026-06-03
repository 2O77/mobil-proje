class TherapistListing {
  const TherapistListing({
    required this.uid,
    required this.displayName,
    required this.sortOrder,
  });

  final String uid;
  final String displayName;
  final int sortOrder;

  factory TherapistListing.fromDoc(String uid, Map<String, dynamic> data) {
    return TherapistListing(
      uid: uid,
      displayName: (data['displayName'] as String?) ?? uid,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
