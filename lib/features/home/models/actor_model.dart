import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Actor Status ───────────────────────────────────
enum ActorStatus { draft, inReview, published, blocked }

extension ActorStatusExtension on ActorStatus {
  String get value {
    switch (this) {
      case ActorStatus.draft:
        return 'Draft';
      case ActorStatus.inReview:
        return 'In Review';
      case ActorStatus.published:
        return 'Published';
      case ActorStatus.blocked:
        return 'Blocked';
    }
  }

  static ActorStatus fromString(String status) {
    switch (status) {
      case 'In Review':
        return ActorStatus.inReview;
      case 'Published':
        return ActorStatus.published;
      case 'Blocked':
        return ActorStatus.blocked;
      case 'Draft':
      default:
        return ActorStatus.draft;
    }
  }
}

// ─── MovieCredit ─────────────────────────────────────────
class MovieCredit {
  const MovieCredit({required this.title, this.role});

  final String title;
  final String? role;

  factory MovieCredit.fromMap(Map<String, dynamic> map) {
    return MovieCredit(
      title: map['title'] as String? ?? '',
      role: map['role'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'role': role ?? '',
    };
  }

  @override
  String toString() => role != null && role!.isNotEmpty
      ? '$title — $role'
      : title;
}

// ─── ActorModel — matches /actors/{actorId} blueprint ──
class ActorModel {
  const ActorModel({
    required this.id,
    required this.name,
    required this.searchName,
    required this.status,
    this.isSearchable = true,
    this.searchKeywords,
    this.avatar,
    this.location,
    this.lastActiveAt,
    this.contactMasked = true,
    this.phone,
    this.email,
    this.height,
    this.photos,
    this.videoUrls,
    this.serialsActed,
    this.moviesActed,
    this.rolesActed,
    this.skills,
    this.languages,
    this.movies,
    this.about,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String searchName;
  final ActorStatus status;
  final bool isSearchable;
  final List<String>? searchKeywords;
  final String? avatar;
  final String? location;
  final DateTime? lastActiveAt;
  final bool contactMasked;
  final String? phone;
  final String? email;
  final String? height;
  final List<String>? photos;
  final List<String>? videoUrls;
  final List<String>? serialsActed;
  final List<String>? moviesActed;
  final List<String>? rolesActed;
  final List<String>? skills;
  final List<String>? languages;
  final List<MovieCredit>? movies;
  final String? about;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Parse from Firestore document snapshot.
  /// Handles both admin-panel field names and legacy Flutter field names.
  factory ActorModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    final movieCredits = _toMovieCreditList(data['movies']);
    final movieTitlesFromCredits = _movieTitlesFromCredits(movieCredits);

    final serialNames = _preferNonEmptyList(
      _toStringList(data['serialsActed'] ?? data['serials'] ?? data['tvSerials']),
      _toStringList(data['projects'] ?? data['tvProjects']),
    );

    final movieNames = _preferNonEmptyList(
      _toStringList(data['moviesActed'] ?? data['movieNames'] ?? data['filmsActed']),
      movieTitlesFromCredits,
    );

    return ActorModel(
      id: snapshot.id,
      // name: prefer 'name', fallback to 'fullName' or firstName+lastName
      name: data['name'] as String? ??
          data['fullName'] as String? ??
          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
      searchName: data['searchName'] as String? ??
          (data['name'] as String? ?? '').toLowerCase(),
      status: ActorStatusExtension.fromString(
          data['status'] as String? ?? 'Draft'),
        isSearchable: data['isSearchable'] as bool? ?? true,
      searchKeywords: _toStringList(data['searchKeywords']),
      // avatar: prefer 'avatar', fallback to 'profileImageUrl'
      avatar: data['avatar'] as String? ?? data['profileImageUrl'] as String?,
      location: data['location'] as String? ??
          data['currentLocation'] as String?,
      lastActiveAt: _toDateTime(data['lastActiveAt']),
      contactMasked: data['contactMasked'] as bool? ?? true,
      // phone: prefer 'phone', fallback to 'phoneNumber'
      phone: data['phone'] as String? ?? data['phoneNumber'] as String?,
      email: data['email'] as String?,
      height: data['height'] as String?,
      photos: _toStringList(data['photos']),
      videoUrls: _toStringList(data['videoUrls']),
      serialsActed: serialNames,
      moviesActed: movieNames,
      rolesActed: _toStringList(data['rolesActed'] ?? data['tags'] ?? data['roleTypes']),
      skills: _toStringList(data['skills'] ?? data['specialSkills']),
      languages: _toStringList(data['languages'] ?? data['languagesKnown']),
      movies: movieCredits,
      about: data['about'] as String?,
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  /// Convert to Firestore-compatible map (for writes).
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'searchName': searchName,
      'isSearchable': isSearchable,
      'searchKeywords': searchKeywords ?? [],
      'avatar': avatar ?? '',
      'location': location ?? '',
      'status': status.value,
      'lastActiveAt':
          lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'contactMasked': contactMasked,
      'phone': phone ?? '',
      'email': email ?? '',
      'height': height ?? '',
      'photos': photos ?? [],
      'videoUrls': videoUrls ?? [],
      'serialsActed': serialsActed ?? [],
      'moviesActed': moviesActed ?? [],
      'rolesActed': rolesActed ?? [],
      'skills': skills ?? [],
      'languages': languages ?? [],
      'movies': (movies ?? []).map((m) => m.toMap()).toList(),
      'about': about ?? '',
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt':
          updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // ── Helpers ──

  static List<String>? _toStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final result = value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return result.isEmpty ? null : result;
    }
    return null;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<MovieCredit>? _toMovieCreditList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final parsed = value
          .whereType<Map>()
          .map((m) => m.map((key, value) => MapEntry(key.toString(), value)))
          .map((m) => MovieCredit.fromMap(m))
          .where((m) => m.title.trim().isNotEmpty)
          .toList();
      return parsed.isEmpty ? null : parsed;
    }
    return null;
  }

  static List<String>? _movieTitlesFromCredits(List<MovieCredit>? credits) {
    if (credits == null || credits.isEmpty) return null;
    final titles = credits
        .map((c) => c.title.trim())
        .where((title) => title.isNotEmpty)
        .toList();
    return titles.isEmpty ? null : titles;
  }

  static List<String>? _preferNonEmptyList(List<String>? primary, List<String>? fallback) {
    if (primary != null && primary.isNotEmpty) return primary;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }
}
