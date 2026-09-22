import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing an advertisement document from Firestore
/// Collection: /advertisements/{adId}
class AdvertisementModel {
  const AdvertisementModel({
    required this.id,
    required this.title,
    required this.bannerUrl,
    this.targetUrl,
    this.placement,
    this.status = 'Active',
    this.priority = 0,
    this.clicks = 0,
    this.createdBy,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String bannerUrl;
  final String? targetUrl;
  final String? placement;
  final String status;
  final int priority;
  final int clicks;
  final String? createdBy;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Whether the ad is currently active based on status and date range.
  bool get isActive {
    if (status != 'Active') return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  factory AdvertisementModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return AdvertisementModel(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Advertisement',
      bannerUrl: data['bannerUrl'] as String? ?? '',
      targetUrl: data['targetUrl'] as String?,
      placement: data['placement'] as String?,
      status: data['status'] as String? ?? 'Active',
      priority: (data['priority'] as num?)?.toInt() ?? 0,
      clicks: (data['clicks'] as num?)?.toInt() ?? 0,
      createdBy: data['createdBy'] as String?,
      startDate: _toDateTime(data['startDate']),
      endDate: _toDateTime(data['endDate']),
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
