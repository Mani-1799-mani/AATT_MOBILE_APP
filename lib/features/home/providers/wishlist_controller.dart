import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final wishlistControllerProvider =
    AsyncNotifierProvider<WishlistController, Set<String>>(
  WishlistController.new,
);

class WishlistController extends AsyncNotifier<Set<String>> {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  List<DocumentReference<Map<String, dynamic>>> _candidateRefs(String uid) => [
        _firestore.collection('users').doc(uid),
        _firestore.collection('actors').doc(uid),
        _firestore.collection('directors').doc(uid),
      ];

  Set<String> _extractIds(Map<String, dynamic>? data) {
    return (data?['wishlistedActorIds'] as List<dynamic>? ?? const [])
        .map((id) => id.toString())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<Set<String>> _loadFromBestAvailableDoc(String uid) async {
    for (final ref in _candidateRefs(uid)) {
      try {
        final doc = await ref.get();
        if (doc.exists) {
          return _extractIds(doc.data());
        }
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          continue;
        }
        rethrow;
      }
    }
    return <String>{};
  }

  Future<void> _persistWishlistToggle({
    required String uid,
    required String actorId,
    required bool wasLiked,
  }) async {
    final updatePayload = {
      'wishlistedActorIds': wasLiked
          ? FieldValue.arrayRemove([actorId])
          : FieldValue.arrayUnion([actorId]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final usersRef = _firestore.collection('users').doc(uid);
    try {
      await usersRef.set(updatePayload, SetOptions(merge: true));
      return;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        rethrow;
      }
    }

    final fallbackRefs = [
      _firestore.collection('actors').doc(uid),
      _firestore.collection('directors').doc(uid),
    ];

    for (final ref in fallbackRefs) {
      try {
        final existing = await ref.get();
        if (!existing.exists) {
          continue;
        }
        await ref.set(updatePayload, SetOptions(merge: true));
        return;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          continue;
        }
        rethrow;
      }
    }

    throw Exception('Wishlist update is not permitted by Firestore rules.');
  }

  @override
  Future<Set<String>> build() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return <String>{};

    return _loadFromBestAvailableDoc(uid);
  }

  bool contains(String actorId) {
    final current = state.valueOrNull ?? const <String>{};
    return current.contains(actorId);
  }

  Future<void> toggleWishlist(String actorId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('You need to be logged in to update wishlist.');
    }

    final current = Set<String>.from(state.valueOrNull ?? const <String>{});
    final wasLiked = current.contains(actorId);

    if (wasLiked) {
      current.remove(actorId);
    } else {
      current.add(actorId);
    }

    state = AsyncData(current);

    try {
      await _persistWishlistToggle(
        uid: uid,
        actorId: actorId,
        wasLiked: wasLiked,
      );
    } catch (_) {
      final reverted = Set<String>.from(current);
      if (wasLiked) {
        reverted.add(actorId);
      } else {
        reverted.remove(actorId);
      }
      state = AsyncData(reverted);
      rethrow;
    }
  }
}
