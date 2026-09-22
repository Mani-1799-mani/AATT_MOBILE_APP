import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aatt/features/home/models/advertisement_model.dart';

/// Provider that streams active advertisements for the "Home" placement,
/// sorted by priority (descending).
final homeAdvertisementsProvider =
    StreamProvider<List<AdvertisementModel>>((ref) {
  final firestore = FirebaseFirestore.instance;

  return firestore
      .collection('advertisements')
      .where('status', isEqualTo: 'Active')
      .where('placement', isEqualTo: 'Home Banner')
      .snapshots()
      .map((snapshot) {
    final ads = snapshot.docs
        .map((doc) => AdvertisementModel.fromFirestore(doc))
        .where((ad) => ad.isActive && ad.bannerUrl.isNotEmpty)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    debugPrint('HomeAds: fetched ${ads.length} active advertisements');
    return ads;
  });
});

/// Increment click count for an ad (fire-and-forget).
Future<void> recordAdClick(String adId) async {
  try {
    await FirebaseFirestore.instance
        .collection('advertisements')
        .doc(adId)
        .update({'clicks': FieldValue.increment(1)});
  } catch (e) {
    debugPrint('recordAdClick error: $e');
  }
}
