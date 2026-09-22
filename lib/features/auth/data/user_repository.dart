import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to interact with the Firestore `actors` collection.
///
/// Admin-created actor profiles are linked to Firebase Auth UIDs
/// via the `linkPhoneToActor` Cloud Function. Once linked, the `uid`
/// field on the actor doc matches the Firebase Auth UID.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _actorsRef =>
      _firestore.collection('actors');

  /// Look up a user document by Firebase Auth UID.
  /// First checks for a doc where the `uid` field matches,
  /// then falls back to checking if the doc ID is the UID.
  Future<({Map<String, dynamic> data, String docId})?> getUserByUid(
      String uid) async {
    try {
      // 1. Query by uid field (works for admin-created docs with custom doc IDs)
      final uidQuery = await _actorsRef
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (uidQuery.docs.isNotEmpty) {
        final matched = uidQuery.docs.first;
        return (data: matched.data(), docId: matched.id);
      }

      // 2. Fallback: direct doc ID lookup (doc ID == UID)
      final doc = await _actorsRef.doc(uid).get();
      if (doc.exists) return (data: doc.data()!, docId: doc.id);

      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }
}
