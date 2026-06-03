import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AppUserRole { individual, caregiver, therapist }

extension AppUserRoleX on AppUserRole {
  String get wire => switch (this) {
        AppUserRole.individual => 'individual',
        AppUserRole.caregiver => 'caregiver',
        AppUserRole.therapist => 'therapist',
      };

  static AppUserRole? fromWire(String? v) {
    switch (v) {
      case 'individual':
        return AppUserRole.individual;
      case 'caregiver':
        return AppUserRole.caregiver;
      case 'therapist':
        return AppUserRole.therapist;
      default:
        return null;
    }
  }
}

class UserProfile {
  const UserProfile({
    required this.uid,
    this.role,
    this.displayName,
    this.diagnosisNotes,
    this.medications = const [],
    this.caregiverIds = const [],
    this.linkedTherapistId,
    this.photoUrl,
    this.fcmToken,
    this.phoneNumber,
  });

  final String uid;
  final AppUserRole? role;
  final String? displayName;
  final String? diagnosisNotes;
  final List<String> medications;
  final List<String> caregiverIds;
  final String? linkedTherapistId;
  final String? photoUrl;
  final String? fcmToken;
  final String? phoneNumber;

  factory UserProfile.fromDoc(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      role: AppUserRoleX.fromWire(data['role'] as String?),
      displayName: data['displayName'] as String?,
      diagnosisNotes: data['diagnosisNotes'] as String?,
      medications: List<String>.from(data['medications'] as List? ?? const []),
      caregiverIds: List<String>.from(data['caregiverIds'] as List? ?? const []),
      linkedTherapistId: data['linkedTherapistId'] as String?,
      photoUrl: data['photoUrl'] as String?,
      fcmToken: data['fcmToken'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        if (role != null) 'role': role!.wire,
        if (displayName != null) 'displayName': displayName,
        if (diagnosisNotes != null) 'diagnosisNotes': diagnosisNotes,
        'medications': medications,
        'caregiverIds': caregiverIds,
        if (linkedTherapistId != null) 'linkedTherapistId': linkedTherapistId,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class Session {
  Session({required this.user, this.profile});

  final User user;
  final UserProfile? profile;

  bool get needsRole => profile?.role == null;
}
