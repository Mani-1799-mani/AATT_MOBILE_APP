import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Announcement Status ────────────────────────────
enum AnnouncementStatus { review, approved, rejected, expired }

extension AnnouncementStatusExtension on AnnouncementStatus {
  String get value {
    switch (this) {
      case AnnouncementStatus.review:
        return 'REVIEW';
      case AnnouncementStatus.approved:
        return 'APPROVED';
      case AnnouncementStatus.rejected:
        return 'REJECTED';
      case AnnouncementStatus.expired:
        return 'EXPIRED';
    }
  }

  static AnnouncementStatus fromString(String status) {
    switch (status.toUpperCase()) {
      case 'REVIEW':
      case 'PENDING':
        return AnnouncementStatus.review;
      case 'APPROVED':
      case 'ACTIVE':
        return AnnouncementStatus.approved;
      case 'REJECTED':
        return AnnouncementStatus.rejected;
      case 'EXPIRED':
        return AnnouncementStatus.expired;
      default:
        return AnnouncementStatus.review;
    }
  }
}

// ─── Tag ─────────────────────────────────────────────
class AnnouncementTag {
  const AnnouncementTag({required this.label, this.color});

  final String label;
  final String? color;

  factory AnnouncementTag.fromMap(Map<String, dynamic> map) {
    return AnnouncementTag(
      label: map['label'] as String? ?? '',
      color: map['color'] as String?,
    );
  }

  /// Parse a tag from any format — could be a Map or a plain String.
  static AnnouncementTag fromDynamic(dynamic value) {
    if (value is Map<String, dynamic>) {
      return AnnouncementTag.fromMap(value);
    }
    if (value is Map) {
      return AnnouncementTag(
        label: value['label']?.toString() ?? '',
        color: value['color']?.toString(),
      );
    }
    if (value is String) {
      return AnnouncementTag(label: value);
    }
    return const AnnouncementTag(label: '');
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        if (color != null) 'color': color,
      };
}

// ─── AnnouncementDoc — matches /announcements/{id} ──
class AnnouncementDoc {
  const AnnouncementDoc({
    required this.id,
    required this.submitterUid,
    required this.submitterName,
    required this.submitterAvatar,
    required this.title,
    required this.description,
    required this.tags,
    required this.status,
    required this.submittedAt,
    required this.reviewedAt,
    required this.reviewedBy,
    this.expiresAt,
    this.thumbnailUrl,
    this.bannerImageUrls = const [],
    this.startsAt,
  });

  final String id;
  final String submitterUid;
  final String submitterName;
  final String submitterAvatar;
  final String title;
  final String description;
  final List<AnnouncementTag> tags;
  final AnnouncementStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final DateTime? expiresAt;
  final String? thumbnailUrl;
  final List<String> bannerImageUrls;
  final DateTime? startsAt;

  /// Returns media URLs in display order while keeping legacy support.
  List<String> get mediaUrls {
    if (bannerImageUrls.isNotEmpty) {
      return bannerImageUrls;
    }
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return [thumbnailUrl!];
    }
    return const [];
  }

  /// Whether the announcement has expired.
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Whether the start date has passed (or no start date is set).
  bool get isStarted =>
      startsAt == null || startsAt!.isBefore(DateTime.now());

  /// Whether the announcement is currently active (started and not expired).
  bool get isCurrentlyActive => isStarted && !isExpired;

  factory AnnouncementDoc.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final d = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};

    var status = AnnouncementStatusExtension.fromString(
      (d['status'] ?? 'REVIEW').toString(),
    );

    // Parse dates safely — could be Timestamp, int (millis), or absent
    DateTime? expiresAt;
    try {
      final v = d['expiresAt'];
      if (v is Timestamp) {
        expiresAt = v.toDate();
      } else if (v is int) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(v);
      }
    } catch (_) {}

    DateTime? startsAt;
    try {
      final v = d['startsAt'];
      if (v is Timestamp) {
        startsAt = v.toDate();
      } else if (v is int) {
        startsAt = DateTime.fromMillisecondsSinceEpoch(v);
      }
    } catch (_) {}

    DateTime submittedAt;
    try {
      final v = d['submittedAt'];
      if (v is Timestamp) {
        submittedAt = v.toDate();
      } else if (v is int) {
        submittedAt = DateTime.fromMillisecondsSinceEpoch(v);
      } else {
        submittedAt = DateTime.now();
      }
    } catch (_) {
      submittedAt = DateTime.now();
    }

    DateTime? reviewedAt;
    try {
      final v = d['reviewedAt'];
      if (v is Timestamp) {
        reviewedAt = v.toDate();
      } else if (v is int) {
        reviewedAt = DateTime.fromMillisecondsSinceEpoch(v);
      }
    } catch (_) {}

    // Auto-expire: if end date has passed, treat as expired regardless of stored status
    if (expiresAt != null &&
        expiresAt.isBefore(DateTime.now()) &&
        status != AnnouncementStatus.expired) {
      status = AnnouncementStatus.expired;
    }

    // Parse tags safely — could be List<Map>, List<String>, or absent
    List<AnnouncementTag> tags;
    try {
      final rawTags = d['tags'];
      if (rawTags is List) {
        tags = rawTags.map((e) => AnnouncementTag.fromDynamic(e)).toList();
      } else {
        tags = const [];
      }
    } catch (_) {
      tags = const [];
    }

    // Parse banner images safely.
    List<String> bannerImageUrls;
    try {
      final rawBannerImages = d['bannerImageUrls'] ?? d['bannerImages'];
      if (rawBannerImages is List) {
        bannerImageUrls = rawBannerImages
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        bannerImageUrls = const [];
      }
    } catch (_) {
      bannerImageUrls = const [];
    }

    return AnnouncementDoc(
      id: doc.id,
      submitterUid: (d['submitterUid'] ?? '').toString(),
      submitterName: (d['submitterName'] ?? '').toString(),
      submitterAvatar: (d['submitterAvatar'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      tags: tags,
      status: status,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt,
      reviewedBy: d['reviewedBy']?.toString(),
      expiresAt: expiresAt,
      thumbnailUrl: d['thumbnailUrl']?.toString(),
      bannerImageUrls: bannerImageUrls,
      startsAt: startsAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'submitterUid': submitterUid,
        'submitterName': submitterName,
        'submitterAvatar': submitterAvatar,
        'title': title,
        'description': description,
        'tags': tags.map((t) => t.toJson()).toList(),
        'status': status.value,
        'submittedAt': Timestamp.fromDate(submittedAt),
        'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
        'reviewedBy': reviewedBy,
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (bannerImageUrls.isNotEmpty) 'bannerImageUrls': bannerImageUrls,
        if (startsAt != null) 'startsAt': Timestamp.fromDate(startsAt!),
      };
}
