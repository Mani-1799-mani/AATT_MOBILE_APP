import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aatt/core/router/app_router.dart';
import 'package:aatt/core/widgets/ui_helpers.dart';
import 'package:aatt/features/home/models/actor_model.dart';
import 'package:aatt/features/home/providers/wishlist_controller.dart';
import 'package:aatt/features/home/widgets/actor_search_body.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  static const int _chunkSize = 10;

  List<List<String>> _chunkIds(List<String> ids) {
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += _chunkSize) {
      final end = (i + _chunkSize) > ids.length ? ids.length : i + _chunkSize;
      chunks.add(ids.sublist(i, end));
    }
    return chunks;
  }

  Future<List<ActorModel>> _fetchActorsByIds(List<String> ids) async {
    if (ids.isEmpty) return const <ActorModel>[];

    final actorsRef = FirebaseFirestore.instance.collection('actors');
    final chunks = _chunkIds(ids);

    final snapshots = await Future.wait(
      chunks.map(
        (chunk) => actorsRef
            .where(FieldPath.documentId, whereIn: chunk)
            .get(),
      ),
    );

    final fetched = snapshots
        .expand((snap) => snap.docs)
        .map((doc) => ActorModel.fromFirestore(doc))
        .toList();

    final byId = {
      for (final actor in fetched) actor.id: actor,
    };

    return ids
        .map((id) => byId[id])
        .whereType<ActorModel>()
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: EmptyStateWidget(
          icon: Icons.lock_outline,
          title: 'Login Required',
          subtitle: 'Please sign in to view your wishlist.',
        ),
      );
    }

    final wishlistAsync = ref.watch(wishlistControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: wishlistAsync.when(
        loading: _buildLoadingGrid,
        error: (error, _) => Center(
          child: Text('Failed to load wishlist: $error'),
        ),
        data: (wishlistIdsSet) {
          final ids = wishlistIdsSet.toList(growable: false);

          if (ids.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.heart_broken_rounded,
              title: 'Your wishlist is empty',
              subtitle: 'Start exploring actors!',
              actionLabel: 'Explore Actors',
              onAction: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.go(AppRoutes.actorHome);
              },
            );
          }

          return FutureBuilder<List<ActorModel>>(
            future: _fetchActorsByIds(ids),
            builder: (context, actorsSnapshot) {
              if (actorsSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingGrid();
              }

              if (actorsSnapshot.hasError) {
                return Center(
                  child: Text('Failed to load wishlisted actors: ${actorsSnapshot.error}'),
                );
              }

              final actors = actorsSnapshot.data ?? const <ActorModel>[];
              if (actors.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.search_off_rounded,
                  title: 'No actors found',
                  subtitle: 'Some wishlisted profiles may have been removed.',
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: actors.length,
                itemBuilder: (context, index) => ActorCard(actor: actors[index]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const ActorCardShimmer(),
    );
  }
}
