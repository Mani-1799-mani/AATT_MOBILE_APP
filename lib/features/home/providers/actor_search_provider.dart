import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aatt/features/home/models/actor_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCH QUERY
// ═══════════════════════════════════════════════════════════════════════════════

/// Raw text from the search bar.
final actorSearchQueryProvider = StateProvider<String>((ref) => '');

// ═══════════════════════════════════════════════════════════════════════════════
// FILTER STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Selected gender filter (null = any).
final advancedGenderProvider = StateProvider<String?>((ref) => null);

/// Current location text filter.
final advancedLocationProvider = StateProvider<String>((ref) => '');

/// Selected languages filter.
final advancedLanguagesProvider = StateProvider<Set<String>>((ref) => {});

/// Selected roles/tags filter.
final advancedRolesProvider = StateProvider<Set<String>>((ref) => {});

/// Helper: check if any filter is active.
final hasActiveFiltersProvider = Provider<bool>((ref) {
  final gender = ref.watch(advancedGenderProvider);
  final location = ref.watch(advancedLocationProvider);
  final languages = ref.watch(advancedLanguagesProvider);
  final roles = ref.watch(advancedRolesProvider);

  return gender != null ||
      location.isNotEmpty ||
      languages.isNotEmpty ||
      roles.isNotEmpty;
});

/// Count of active filters.
final activeFilterCountProvider = Provider<int>((ref) {
  int count = 0;
  if (ref.watch(advancedGenderProvider) != null) count++;
  if (ref.watch(advancedLocationProvider).isNotEmpty) count++;
  count += ref.watch(advancedLanguagesProvider).length;
  count += ref.watch(advancedRolesProvider).length;
  return count;
});

// ═══════════════════════════════════════════════════════════════════════════════
// PAGINATION STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Current page number (0-indexed) for pagination.
final currentPageProvider = StateProvider<int>((ref) => 0);

/// Items per page for pagination.
final itemsPerPageProvider = StateProvider<int>((ref) => 40);

// ═══════════════════════════════════════════════════════════════════════════════
// COMBINED SEARCH PROVIDER — text search + filters
// ═══════════════════════════════════════════════════════════════════════════════

const _initialFetchLimit = 1000;  // Fetch up to 1000 actors for complete results

/// Provides all filtered/searched actors for pagination.
/// This fetches all published actors and applies filters/search.
final allFilteredActorsProvider = FutureProvider<List<ActorModel>>((ref) async {
  final query = ref.watch(actorSearchQueryProvider).toLowerCase().trim();
  final gender = ref.watch(advancedGenderProvider)?.toLowerCase().trim();
  final location = ref.watch(advancedLocationProvider).toLowerCase().trim();
  final languages =
      ref.watch(advancedLanguagesProvider).map((e) => e.toLowerCase().trim()).toSet();
  final roles =
      ref.watch(advancedRolesProvider).map((e) => e.toLowerCase().trim()).toSet();

  final hasFilters = gender != null ||
      location.isNotEmpty ||
      languages.isNotEmpty ||
      roles.isNotEmpty;

  final firestore = FirebaseFirestore.instance;
  final actorsRef = firestore.collection('actors');

  try {
    // Fetch all published actors (increased limit to get complete dataset)
    final snapshot = await actorsRef
        .where('status', isEqualTo: ActorStatus.published.value)
        .limit(_initialFetchLimit)
        .get();

    final rawDataById = <String, Map<String, dynamic>>{
      for (final doc in snapshot.docs) doc.id: {'id': doc.id, ...doc.data()},
    };

    var actors = snapshot.docs
        .map((doc) => ActorModel.fromFirestore(doc))
        .where((actor) => _isVisibleActor(actor, rawDataById[actor.id] ?? const {}))
        .toList();

    if (query.isNotEmpty) {
      actors = actors
          .where((actor) => _matchesSearchQuery(
                query,
                actor,
                rawDataById[actor.id] ?? const {},
              ))
          .toList();
    }

    // Apply filters if any are active
    if (hasFilters) {
      // Gender filter
      if (gender != null && gender.isNotEmpty) {
        actors = actors.where((a) {
          final raw = rawDataById[a.id] ?? {};
          final g = (raw['gender'] ?? raw['sex'] ?? '').toString().toLowerCase().trim();
          if (g.isEmpty) return false;
          return g == gender || g.startsWith(gender) || gender.startsWith(g);
        }).toList();
      }

      // Location filter
      if (location.isNotEmpty) {
        actors = actors.where((a) {
          final actorLocation = (a.location ?? '').toLowerCase().trim();
          if (actorLocation.isEmpty) return false;
          return actorLocation.contains(location) ||
              location.contains(actorLocation);
        }).toList();
      }

      // Languages filter
      if (languages.isNotEmpty) {
        actors = actors.where((a) {
          final actorLanguages = {
            ...(a.languages ?? []).map((lang) => lang.toLowerCase().trim()),
            ...((rawDataById[a.id]?['languagesKnown'] as List<dynamic>? ?? const [])
                .map((lang) => lang.toString().toLowerCase().trim())),
          };
          return _matchesAnyToken(languages, actorLanguages);
        }).toList();
      }

      // Roles filter
      if (roles.isNotEmpty) {
        actors = actors.where((a) {
          final actorRoles =
              (a.rolesActed ?? []).map((r) => r.toLowerCase().trim()).toSet();
          final actorSkills =
              (a.skills ?? []).map((s) => s.toLowerCase().trim()).toSet();
          final actorKeywords =
              (a.searchKeywords ?? []).map((k) => k.toLowerCase().trim()).toSet();
          final combined = {...actorRoles, ...actorSkills, ...actorKeywords};
          return _matchesAnyToken(roles, combined);
        }).toList();
      }
    }

    if (query.isNotEmpty) {
      actors.sort(
        (a, b) => _compareBySearchRank(
          a,
          b,
          query,
          rawDataById[a.id] ?? const {},
          rawDataById[b.id] ?? const {},
        ),
      );
    } else {
      actors.sort(_compareByBrowseOrder);
    }

    return actors;
  } catch (e) {
    debugPrint('ActorSearch error: $e');
    rethrow;
  }
});

/// Provides paginated actors based on current page and items per page.
final actorSearchProvider = FutureProvider<List<ActorModel>>((ref) async {
  final currentPage = ref.watch(currentPageProvider);
  final itemsPerPage = ref.watch(itemsPerPageProvider);
  final allActors = await ref.watch(allFilteredActorsProvider.future);

  // Calculate pagination bounds
  final startIndex = currentPage * itemsPerPage;
  final endIndex = startIndex + itemsPerPage;

  // Return paginated slice
  if (startIndex >= allActors.length) {
    return const [];
  }

  return allActors.sublist(
    startIndex,
    endIndex > allActors.length ? allActors.length : endIndex,
  );
});

/// Provides total count of filtered actors (for pagination UI).
final totalActorsCountProvider = FutureProvider<int>((ref) async {
  final allActors = await ref.watch(allFilteredActorsProvider.future);
  return allActors.length;
});

/// Check if any [selected] token partially matches any value in [haystack].
bool _matchesAnyToken(Set<String> selected, Set<String> haystack) {
  if (selected.isEmpty) return true;
  for (final needle in selected) {
    for (final value in haystack) {
      if (value == needle || value.contains(needle) || needle.contains(value)) {
        return true;
      }
    }
  }
  return false;
}

bool _isVisibleActor(ActorModel actor, Map<String, dynamic> raw) {
  final isSearchable = raw['isSearchable'];
  if (isSearchable is bool && !isSearchable) return false;
  // Drop incomplete profiles that render as empty/blank grid tiles.
  if (actor.name.trim().isEmpty) return false;
  final avatar = (actor.avatar ?? '').trim();
  if (avatar.isEmpty) return false;
  return actor.status == ActorStatus.published && actor.isSearchable;
}

bool _matchesSearchQuery(
  String query,
  ActorModel actor,
  Map<String, dynamic> raw,
) {
  final tokens = query
      .split(RegExp(r'\s+'))
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return true;

  final haystack = _buildSearchTerms(actor, raw);
  return tokens.every(
    (token) => haystack.any((value) => value.contains(token)),
  );
}

Set<String> _buildSearchTerms(ActorModel actor, Map<String, dynamic> raw) {
  final values = <String>{
    actor.name,
    actor.searchName,
    actor.location ?? '',
    actor.about ?? '',
    ...(actor.searchKeywords ?? const <String>[]),
    ...(actor.rolesActed ?? const <String>[]),
    ...(actor.skills ?? const <String>[]),
    ...(actor.languages ?? const <String>[]),
    ...((raw['languagesKnown'] as List<dynamic>? ?? const <dynamic>[])
        .map((value) => value.toString())),
    (raw['gender'] ?? raw['sex'] ?? '').toString(),
  };

  return values
      .map((value) => value.toLowerCase().trim())
      .where((value) => value.isNotEmpty)
      .toSet();
}

int _compareBySearchRank(
  ActorModel a,
  ActorModel b,
  String query,
  Map<String, dynamic> rawA,
  Map<String, dynamic> rawB,
) {
  final scoreDiff = _searchRank(b, query, rawB) - _searchRank(a, query, rawA);
  if (scoreDiff != 0) return scoreDiff;
  return _compareByBrowseOrder(a, b);
}

int _searchRank(ActorModel actor, String query, Map<String, dynamic> raw) {
  final name = actor.name.toLowerCase().trim();
  final searchName = actor.searchName.toLowerCase().trim();
  final location = (actor.location ?? '').toLowerCase().trim();
  final roles = (actor.rolesActed ?? const <String>[])
      .map((value) => value.toLowerCase().trim())
      .toList();
  final skills = (actor.skills ?? const <String>[])
      .map((value) => value.toLowerCase().trim())
      .toList();
  final languages = {
    ...(actor.languages ?? const <String>[])
        .map((value) => value.toLowerCase().trim()),
    ...((raw['languagesKnown'] as List<dynamic>? ?? const <dynamic>[])
        .map((value) => value.toString().toLowerCase().trim())),
  };

  var score = 0;
  if (name == query) score += 200;
  if (searchName == query) score += 180;
  if (name.startsWith(query)) score += 120;
  if (searchName.startsWith(query)) score += 110;
  if (roles.any((value) => value.startsWith(query))) score += 80;
  if (skills.any((value) => value.startsWith(query))) score += 70;
  if (languages.any((value) => value.startsWith(query))) score += 60;
  if (location.startsWith(query)) score += 50;
  if (_buildSearchTerms(actor, raw).any((value) => value.contains(query))) {
    score += 25;
  }
  return score;
}

int _compareByBrowseOrder(ActorModel a, ActorModel b) {
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

