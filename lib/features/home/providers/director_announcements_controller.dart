import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aatt/features/home/models/announcement_model.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class DirectorAnnouncementsState {
  const DirectorAnnouncementsState({
    this.items = const [],
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.lastDoc,
  });

  final List<AnnouncementDoc> items;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;
  final DocumentSnapshot? lastDoc;

  DirectorAnnouncementsState copyWith({
    List<AnnouncementDoc>? items,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    DocumentSnapshot? lastDoc,
    bool clearError = false,
    bool clearLastDoc = false,
  }) {
    return DirectorAnnouncementsState(
      items: items ?? this.items,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      lastDoc: clearLastDoc ? null : (lastDoc ?? this.lastDoc),
    );
  }
}

// ─── Controller ──────────────────────────────────────────────────────────────

class DirectorAnnouncementsController
    extends StateNotifier<DirectorAnnouncementsState> {
  DirectorAnnouncementsController({
    required this.directorUid,
  }) : super(
          directorUid.isEmpty
              ? const DirectorAnnouncementsState(
                  isInitialLoading: false,
                  hasMore: false,
                )
              : const DirectorAnnouncementsState(),
        ) {
    if (directorUid.isNotEmpty) {
      Future.microtask(refresh);
    }
  }

  final String directorUid;

  static const int _fetchLimit = 200;

  int _tabIndex = 0;
  int get tabIndex => _tabIndex;

  // ── Tab labels ──

  static const tabLabels = ['Active', 'Under Review', 'Expired'];

  // ── Query builder ──

  Query<Map<String, dynamic>> _buildQuery() {
    final collection = FirebaseFirestore.instance.collection('announcements');
    return collection
        .where('submitterUid', isEqualTo: directorUid)
        .where(
          'status',
          whereIn: ['APPROVED', 'ACTIVE', 'REVIEW', 'PENDING', 'EXPIRED', 'REJECTED'],
        )
        .limit(_fetchLimit);
  }

  // ── Public API ──

  Future<void> changeTab(int index) async {
    if (_tabIndex == index) return;
    _tabIndex = index;
    await refresh();
  }

  Future<void> refresh() async {
    if (directorUid.isEmpty) {
      state = const DirectorAnnouncementsState(
        isInitialLoading: false,
        hasMore: false,
      );
      return;
    }
    state = const DirectorAnnouncementsState();
    await _fetchPage(isInitial: true);
  }

  Future<void> loadMore() async {
    return;
  }

  Future<void> _fetchPage({required bool isInitial}) async {
    if (isInitial) {
      state = state.copyWith(
        isInitialLoading: true,
        clearError: true,
        clearLastDoc: true,
        items: const [],
        hasMore: true,
      );
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final query = _buildQuery();

      if (isInitial) {
        try {
          final cachedSnapshot = await query.get(const GetOptions(source: Source.cache));
          if (cachedSnapshot.docs.isNotEmpty) {
            _applySnapshot(cachedSnapshot.docs);
          }
        } catch (_) {
          // Ignore cache miss and continue to network.
        }
      }

      final snapshot = await query.get();
      _applySnapshot(snapshot.docs);
    } catch (e) {
      state = state.copyWith(
        error: e,
        isInitialLoading: false,
        isLoadingMore: false,
      );
    }
  }

  void _applySnapshot(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var parsed = <AnnouncementDoc>[];
    for (final doc in docs) {
      try {
        parsed.add(AnnouncementDoc.fromFirestore(doc));
      } catch (e) {
        debugPrint('Skipping malformed announcement ${doc.id}: $e');
      }
    }

    parsed.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    if (_tabIndex == 0) {
      parsed = parsed
          .where((item) =>
              item.status == AnnouncementStatus.approved &&
              item.isCurrentlyActive)
          .toList();
    }
    if (_tabIndex == 1) {
      parsed = parsed
          .where((item) => item.status == AnnouncementStatus.review)
          .toList();
    }
    if (_tabIndex == 2) {
      parsed = parsed
          .where((item) =>
              item.status == AnnouncementStatus.expired ||
              item.status == AnnouncementStatus.rejected ||
              item.isExpired)
          .toList();
    }

    state = state.copyWith(
      items: parsed,
      lastDoc: null,
      hasMore: false,
      isInitialLoading: false,
      isLoadingMore: false,
      clearError: true,
    );
  }

  /// Delete an announcement by its ID.
  Future<void> deleteAnnouncement(String announcementId) async {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(announcementId)
        .delete();
    state = state.copyWith(
      items: state.items.where((a) => a.id != announcementId).toList(),
    );
  }

  /// Close an active announcement (set status to EXPIRED).
  Future<void> closeAnnouncement(String announcementId) async {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(announcementId)
        .update({
      'status': 'EXPIRED',
      'reviewedAt': Timestamp.fromDate(DateTime.now()),
      'reviewedBy': null,
    });
    state = state.copyWith(
      items: state.items.where((a) => a.id != announcementId).toList(),
    );
  }

  /// Repost an expired announcement (set status back to REVIEW).
  Future<void> repostAnnouncement(String announcementId) async {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(announcementId)
        .update({
      'status': 'REVIEW',
      'submittedAt': Timestamp.fromDate(DateTime.now()),
      'reviewedAt': null,
      'reviewedBy': null,
    });
    state = state.copyWith(
      items: state.items.where((a) => a.id != announcementId).toList(),
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final directorAnnouncementsProvider = StateNotifierProvider.family<
    DirectorAnnouncementsController,
    DirectorAnnouncementsState,
    String>(
  (ref, uid) => DirectorAnnouncementsController(directorUid: uid),
);

// ─── Create Announcement ─────────────────────────────────────────────────────

class CreateAnnouncementState {
  const CreateAnnouncementState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.error,
  });

  final bool isSubmitting;
  final bool isSuccess;
  final Object? error;
}

class CreateAnnouncementController extends StateNotifier<CreateAnnouncementState> {
  CreateAnnouncementController() : super(const CreateAnnouncementState());

  Future<bool> submit({
    required String submitterUid,
    required String submitterName,
    required String submitterAvatar,
    required String title,
    required String description,
    required List<AnnouncementTag> tags,
    required String type,
    String? thumbnailUrl,
    List<String> bannerImageUrls = const [],
    DateTime? startsAt,
    DateTime? expiresAt,
  }) async {
    state = const CreateAnnouncementState(isSubmitting: true);

    try {
      final allTags = <AnnouncementTag>[
        AnnouncementTag(label: type),
        ...tags,
      ];

      final doc = AnnouncementDoc(
        id: '', // Firestore will generate
        submitterUid: submitterUid,
        submitterName: submitterName,
        submitterAvatar: submitterAvatar,
        title: title,
        description: description,
        tags: allTags,
        status: AnnouncementStatus.review,
        submittedAt: DateTime.now(),
        reviewedAt: null,
        reviewedBy: null,
        expiresAt: expiresAt,
        thumbnailUrl: thumbnailUrl,
        bannerImageUrls: bannerImageUrls,
        startsAt: startsAt,
      );

      await FirebaseFirestore.instance
          .collection('announcements')
          .add(doc.toJson());

      state = const CreateAnnouncementState(isSuccess: true);
      return true;
    } catch (e) {
      state = CreateAnnouncementState(error: e);
      return false;
    }
  }

  void reset() {
    state = const CreateAnnouncementState();
  }
}

final createAnnouncementProvider =
    StateNotifierProvider.autoDispose<CreateAnnouncementController, CreateAnnouncementState>(
  (ref) => CreateAnnouncementController(),
);

// ─── Update Announcement ─────────────────────────────────────────────────────

Future<void> updateAnnouncement({
  required String announcementId,
  required String title,
  required String description,
  required List<AnnouncementTag> tags,
  String? thumbnailUrl,
  List<String>? bannerImageUrls,
  DateTime? startsAt,
  DateTime? expiresAt,
}) async {
  final data = <String, dynamic>{
    'title': title,
    'description': description,
    'tags': tags.map((t) => t.toJson()).toList(),
    'status': 'REVIEW',
    'submittedAt': Timestamp.fromDate(DateTime.now()),
    'reviewedAt': null,
    'reviewedBy': null,
  };
  if (thumbnailUrl != null) {
    data['thumbnailUrl'] = thumbnailUrl;
  } else {
    data['thumbnailUrl'] = FieldValue.delete();
  }
  if (bannerImageUrls != null) {
    if (bannerImageUrls.isNotEmpty) {
      data['bannerImageUrls'] = bannerImageUrls;
    } else {
      data['bannerImageUrls'] = FieldValue.delete();
    }
  }
  if (startsAt != null) {
    data['startsAt'] = Timestamp.fromDate(startsAt);
  } else {
    data['startsAt'] = FieldValue.delete();
  }
  if (expiresAt != null) {
    data['expiresAt'] = Timestamp.fromDate(expiresAt);
  } else {
    data['expiresAt'] = FieldValue.delete();
  }
  await FirebaseFirestore.instance
      .collection('announcements')
      .doc(announcementId)
      .update(data);
}
