import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ActorProfileUpdateRequestItem {
  const ActorProfileUpdateRequestItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.actorId,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.profileDiffs = const [],
    this.requestedUpdates = const {},
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final String actorId;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final List<Map<String, dynamic>> profileDiffs;
  final Map<String, dynamic> requestedUpdates;

  factory ActorProfileUpdateRequestItem.fromJson(Map<String, dynamic> json) {
    return ActorProfileUpdateRequestItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      actorId: json['actorId']?.toString() ?? '',
      createdAt: _parseDateTime(json['createdAt']),
      reviewedAt: _parseDateTime(json['reviewedAt']),
      reviewedBy: json['reviewedBy']?.toString(),
      profileDiffs: ((json['profileDiffs'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((item) => item.map(
                    (key, value) => MapEntry(key.toString(), value),
                  )))
          .toList(),
      requestedUpdates: (json['requestedUpdates'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value),
          ) ??
          const {},
    );
  }
}

class SubmitProfileUpdateResult {
  const SubmitProfileUpdateResult({
    required this.success,
    required this.approvalId,
    required this.action,
    required this.changedFieldCount,
    this.profileDiffs = const [],
  });

  final bool success;
  final String approvalId;
  final String action;
  final int changedFieldCount;
  final List<Map<String, dynamic>> profileDiffs;

  factory SubmitProfileUpdateResult.fromJson(Map<String, dynamic> json) {
    return SubmitProfileUpdateResult(
      success: json['success'] == true,
      approvalId: json['approvalId']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      changedFieldCount: (json['changedFieldCount'] as num?)?.toInt() ?? 0,
      profileDiffs: ((json['profileDiffs'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((item) => item.map(
                    (key, value) => MapEntry(key.toString(), value),
                  )))
          .toList(),
    );
  }
}

class ActorProfileUpdateApi {
  ActorProfileUpdateApi({http.Client? client}) : _client = client ?? http.Client();

  static const _configuredBaseUrl = String.fromEnvironment('AATT_API_BASE_URL');

  final http.Client _client;

  Future<SubmitProfileUpdateResult> submitProfileUpdate({
    String? actorId,
    required Map<String, dynamic> updates,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to request profile changes.');
    }

    final idToken = await user.getIdToken();
    final uri = _buildUri('/api/actors/profile-update');
    final payload = <String, dynamic>{
      if (actorId != null && actorId.isNotEmpty) 'actorId': actorId,
      'updates': updates,
    };

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(payload),
    );

    final json = _decodeJson(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_errorMessageFromResponse(json, response.statusCode));
    }

    return SubmitProfileUpdateResult.fromJson(json);
  }

  Future<List<ActorProfileUpdateRequestItem>> fetchProfileUpdateHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to view profile update history.');
    }

    final idToken = await user.getIdToken();
    final uri = _buildUri('/api/actors/profile-update');
    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
    );

    final json = _decodeJson(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessageFromResponse(json, response.statusCode));
    }

    final items = json['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map>()
        .map((item) => ActorProfileUpdateRequestItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
  }

  Uri _buildUri(String path) {
    if (_configuredBaseUrl.isNotEmpty) {
      return Uri.parse('$_configuredBaseUrl$path');
    }
    if (kIsWeb) {
      return Uri.parse(path);
    }
    throw Exception(
      'Missing API base URL. Provide --dart-define=AATT_API_BASE_URL=https://your-backend.com',
    );
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) return const {};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  String _errorMessageFromResponse(Map<String, dynamic> json, int statusCode) {
    final candidates = [
      json['message'],
      json['error'],
      json['details'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return 'Request failed with status $statusCode';
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }
  }
  return null;
}