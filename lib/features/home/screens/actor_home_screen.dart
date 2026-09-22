import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/home/widgets/actor_search_body.dart';

/// Provider to fetch the current actor's display name from Firestore.
/// Accepts actor doc ID (which may differ from Firebase Auth UID for admin-created actors).
final actorNameProvider = FutureProvider.family<String, String>((ref, docId) async {
  if (docId.isEmpty) return 'Actor';

  // Try direct doc lookup
  final doc = await FirebaseFirestore.instance.collection('actors').doc(docId).get();
  if (doc.exists) {
    final data = doc.data()!;
    return data['name'] as String? ??
        data['fullName'] as String? ??
        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
  }

  // Fallback: query by uid field (docId might be a Firebase Auth UID)
  final uidQuery = await FirebaseFirestore.instance
      .collection('actors')
      .where('uid', isEqualTo: docId)
      .limit(1)
      .get();
  if (uidQuery.docs.isNotEmpty) {
    final data = uidQuery.docs.first.data();
    return data['name'] as String? ??
        data['fullName'] as String? ??
        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
  }

  return 'Actor';
});

/// Actor Home Screen — uses the same shared search UI as the Director portal.
class ActorHomeScreen extends ConsumerWidget {
  const ActorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final nameAsync = ref.watch(actorNameProvider(authState.actorDocId ?? authState.uid ?? ''));

    final userName = nameAsync.when(
      data: (name) => name.isNotEmpty ? name : (authState.phoneNumber ?? 'Actor'),
      loading: () => 'Loading…',
      error: (_, _) => authState.phoneNumber ?? 'Actor',
    );

    return ActorSearchBody(
      welcomeSubtitle: 'Artistes Association of Telugu Television',
      userName: userName,
      onLogout: () => ref.read(authControllerProvider.notifier).signOut(),
    );
  }
}
