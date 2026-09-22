import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/core/services/actor_profile_update_api.dart';
import 'package:aatt/features/home/models/actor_model.dart';

// ─── Actor Profile Provider ─────────────────────────────────────────────────
// Fetches the currently-logged-in actor's full profile from Firestore.

final actorProfileProvider =
    FutureProvider.family<ActorModel?, String>((ref, docId) async {
  if (docId.isEmpty) return null;

  // Try direct doc ID lookup first
  final doc = await FirebaseFirestore.instance
      .collection('actors')
      .doc(docId)
      .get();

  if (doc.exists) return ActorModel.fromFirestore(doc);

  // Fallback: query by uid field (docId might be a Firebase Auth UID)
  final uidQuery = await FirebaseFirestore.instance
      .collection('actors')
      .where('uid', isEqualTo: docId)
      .limit(1)
      .get();

  if (uidQuery.docs.isNotEmpty) {
    return ActorModel.fromFirestore(uidQuery.docs.first);
  }

  return null;
});

final currentActorProfileProvider = FutureProvider<ActorModel?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final uid = auth.uid ?? '';
  if (uid.isEmpty) return null;

  final actors = FirebaseFirestore.instance.collection('actors');

  // Use actorDocId (reliably set by linkPhoneToActor Cloud Function) if available
  final docId = auth.actorDocId ?? uid;
  final directDoc = await actors.doc(docId).get();
  if (directDoc.exists) {
    return ActorModel.fromFirestore(directDoc);
  }

  // Fallback: query by uid field (for already-linked profiles)
  final uidQuery = await actors.where('uid', isEqualTo: uid).limit(1).get();
  if (uidQuery.docs.isNotEmpty) {
    return ActorModel.fromFirestore(uidQuery.docs.first);
  }

  return null;
});

final actorProfileUpdateApiProvider = Provider<ActorProfileUpdateApi>((ref) {
  return ActorProfileUpdateApi();
});

final actorProfileUpdateHistoryProvider = FutureProvider<List<ActorProfileUpdateRequestItem>>((ref) async {
  final api = ref.watch(actorProfileUpdateApiProvider);
  try {
    return await api.fetchProfileUpdateHistory();
  } catch (_) {
    final auth = ref.read(authControllerProvider);
    final uid = auth.uid;
    if (uid == null || uid.isEmpty) return const [];

    final snapshot = await FirebaseFirestore.instance
        .collection('approvals')
        .where('actorId', isEqualTo: uid)
      .limit(50)
        .get();

    return snapshot.docs
        .map((doc) => ActorProfileUpdateRequestItem.fromJson({
              ...doc.data(),
              'id': doc.id,
            }))
        .toList();
  }
});

// ─── Approval Submission ────────────────────────────────────────────────────

/// Submits a profile-update approval request.
/// Only includes fields that were actually modified.
Future<void> submitProfileApproval({
  required String requesterUid,
  required String actorDocId,
  required String actorName,
  String? actorAvatar,
  required Map<String, dynamic> requestedChanges,
}) async {
  if (requestedChanges.isEmpty) return;

  final api = ActorProfileUpdateApi();
  try {
    await api.submitProfileUpdate(
      actorId: actorDocId,
      updates: requestedChanges,
    );
    return;
  } catch (_) {
    if (requesterUid.isEmpty) {
      rethrow;
    }

    await FirebaseFirestore.instance.collection('approvals').add({
      'type': 'profile_update',
      'title': 'Profile update request',
      'description': 'Actor requested profile changes for admin review.',
      'status': 'PENDING',
      'actorId': requesterUid,
      'actorDocId': actorDocId,
      'actorName': actorName,
      'actorAvatar': actorAvatar ?? '',
      'requestedChanges': requestedChanges,
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'flutter_app',
    });
  }
}
