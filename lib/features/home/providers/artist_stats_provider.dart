import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds count of Active (Published), Inactive (Draft), and Blocked artists.
class ArtistStats {
  const ArtistStats({
    this.active = 0,
    this.inactive = 0,
    this.blocked = 0,
  });

  final int active;
  final int inactive;
  final int blocked;
}

/// Fetches artist counts by status from Firestore using COUNT aggregations.
final artistStatsProvider = FutureProvider<ArtistStats>((ref) async {
  final actors = FirebaseFirestore.instance.collection('actors');

  final results = await Future.wait([
    actors
        .where('status', isEqualTo: 'Published')
        .count()
        .get(),
    actors
        .where('status', isEqualTo: 'Draft')
        .count()
        .get(),
    actors
        .where('status', isEqualTo: 'Blocked')
        .count()
        .get(),
  ]);

  return ArtistStats(
    active: results[0].count ?? 0,
    inactive: results[1].count ?? 0,
    blocked: results[2].count ?? 0,
  );
});
