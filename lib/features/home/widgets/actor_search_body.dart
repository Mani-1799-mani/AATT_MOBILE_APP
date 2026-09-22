import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aatt/core/router/app_router.dart';
import 'package:aatt/core/widgets/ui_helpers.dart';
import 'package:aatt/features/home/providers/actor_search_provider.dart';
import 'package:aatt/features/home/models/actor_model.dart';
import 'package:aatt/features/home/widgets/wishlist_heart_button.dart';
import 'package:aatt/features/home/widgets/advertisement_banner.dart';

// Design Tokens
class _C {
  _C._();
  static const blue = Color(0xFF1652F0);
  static const blueDark = Color(0xFF1D4ED8);
  static const blueLight = Color(0xFFD9E8F7);
  static const bluePale = Color(0xFFEFF6FF);
  static const ink = Color(0xFF1D1C31);
  static const inkSoft = Color(0xFF64748B);
  static const border = Color(0xFFE5E7EB);
  static const bg = Color(0xFFD9E8F7);
  static const card = Colors.white;
  static const chip = Color(0xFFF3F4F6);
  static const chipText = Color(0xFF6B7280);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SHARED WIDGET — used by BOTH Actor and Director home screens
// ═══════════════════════════════════════════════════════════════════════════════

class ActorSearchBody extends ConsumerStatefulWidget {
  const ActorSearchBody({
    super.key,
    required this.welcomeSubtitle,
    required this.userName,
    this.onLogout,
  });

  final String welcomeSubtitle;
  final String userName;
  final VoidCallback? onLogout;

  @override
  ConsumerState<ActorSearchBody> createState() => _ActorSearchBodyState();
}

class _ActorSearchBodyState extends ConsumerState<ActorSearchBody> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  void _updateSearchQuery(String value, {bool immediate = false}) {
    _searchDebounce?.cancel();
    // Reset to first page when search changes
    ref.read(currentPageProvider.notifier).state = 0;
    
    if (immediate) {
      ref.read(actorSearchQueryProvider.notifier).state = value;
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(actorSearchQueryProvider.notifier).state = value;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actorsAsync = ref.watch(actorSearchProvider);
    final currentQuery = ref.watch(actorSearchQueryProvider);
    final filterCount = ref.watch(activeFilterCountProvider);
    final hasFilters = ref.watch(hasActiveFiltersProvider);

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          // Header area
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_C.blueLight, _C.bg],
                stops: [0.65, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Greeting header with logo
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: Row(
                      children: [
                        // Logo with circle border
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: _C.ink,
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: SvgPicture.asset(
                                'assets/images/logo.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.welcomeSubtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _C.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Welcome, ${widget.userName}',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _C.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              context.go(AppRoutes.actorAnnouncements),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                const Icon(
                                    Icons.notifications_none_rounded,
                                    color: _C.ink,
                                    size: 22),
                                Positioned(
                                  right: 1,
                                  top: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar + Filter Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Row(
                      children: [
                        // Search bar
                        Expanded(
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      _C.border.withValues(alpha: 0.6)),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      _C.blue.withValues(alpha: 0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onChanged: _updateSearchQuery,
                              onSubmitted: (value) => _updateSearchQuery(
                                value,
                                immediate: true,
                              ),
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: _C.ink),
                              decoration: InputDecoration(
                                hintText:
                                    'Search by name, role, skill, location',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 14,
                                  color:
                                      _C.ink.withValues(alpha: 0.4),
                                ),
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(
                                      left: 16, right: 10),
                                  child: Icon(Icons.search_rounded,
                                      color: _C.blue, size: 22),
                                ),
                                prefixIconConstraints:
                                    const BoxConstraints(
                                        minWidth: 0, minHeight: 0),
                                suffixIcon: currentQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: _C.inkSoft),
                                        onPressed: () {
                                          _searchDebounce?.cancel();
                                          _searchController.clear();
                                          ref
                                              .read(
                                                  actorSearchQueryProvider
                                                      .notifier)
                                              .state = '';
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 15),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Filter button
                        GestureDetector(
                          onTap: () => _showFilterSheet(context),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: hasFilters ? _C.blue : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: hasFilters
                                    ? _C.blue
                                    : _C.border.withValues(alpha: 0.6),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: hasFilters
                                      ? _C.blue.withValues(alpha: 0.25)
                                      : _C.blue.withValues(alpha: 0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  color: hasFilters
                                      ? Colors.white
                                      : _C.inkSoft,
                                  size: 22,
                                ),
                                if (filterCount > 0)
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$filterCount',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Active filter chips
                  if (hasFilters)
                    _ActiveFilterChips(
                      onClearAll: () => _resetAllFilters(),
                    ),

                  if (!hasFilters) const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Actor grid with pagination
          Expanded(
            child: actorsAsync.when(
              data: (actors) {
                final totalCountAsync = ref.watch(totalActorsCountProvider);
                
                if (actors.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      const AdvertisementBanner(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: EmptyStateWidget(
                          icon: hasFilters
                              ? Icons.filter_list_off_rounded
                              : Icons.search_off_rounded,
                          title: hasFilters
                              ? 'No matching actors'
                              : currentQuery.isEmpty
                                  ? 'No actors available yet'
                                  : 'No results found',
                          subtitle: hasFilters
                              ? 'Try adjusting your filters'
                              : 'Try different search terms',
                        ),
                      ),
                    ],
                  );
                }
                
                return Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          const SliverToBoxAdapter(
                            child: AdvertisementBanner(),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.62,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => ActorCard(actor: actors[index]),
                                childCount: actors.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Pagination controls
                    _PaginationControls(
                      totalCountAsync: totalCountAsync,
                    ),
                  ],
                );
              },
              loading: () => _buildLoadingGrid(),
              error: (error, _) => ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const AdvertisementBanner(),
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load actors.\n$error',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: Colors.red[400], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetAllFilters() {
    ref.read(advancedGenderProvider.notifier).state = null;
    ref.read(advancedLocationProvider.notifier).state = '';
    ref.read(advancedLanguagesProvider.notifier).state = {};
    ref.read(advancedRolesProvider.notifier).state = {};
    // Reset pagination when filters are cleared
    ref.read(currentPageProvider.notifier).state = 0;
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterBottomSheet(
        onReset: _resetAllFilters,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVE FILTER CHIPS — shown below search bar when filters are active
// ═══════════════════════════════════════════════════════════════════════════════

class _ActiveFilterChips extends ConsumerWidget {
  const _ActiveFilterChips({required this.onClearAll});
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gender = ref.watch(advancedGenderProvider);
    final location = ref.watch(advancedLocationProvider);
    final languages = ref.watch(advancedLanguagesProvider);
    final roles = ref.watch(advancedRolesProvider);

    final chips = <_ActiveChipData>[];

    if (gender != null) {
      chips.add(_ActiveChipData(
        label: gender[0].toUpperCase() + gender.substring(1),
        onRemove: () =>
            ref.read(advancedGenderProvider.notifier).state = null,
      ));
    }
    if (location.isNotEmpty) {
      chips.add(_ActiveChipData(
        label: location,
        onRemove: () =>
            ref.read(advancedLocationProvider.notifier).state = '',
      ));
    }
    for (final lang in languages) {
      chips.add(_ActiveChipData(
        label: lang,
        onRemove: () {
          final updated = Set<String>.from(languages)..remove(lang);
          ref.read(advancedLanguagesProvider.notifier).state = updated;
        },
      ));
    }
    for (final role in roles) {
      chips.add(_ActiveChipData(
        label: role,
        onRemove: () {
          final updated = Set<String>.from(roles)..remove(role);
          ref.read(advancedRolesProvider.notifier).state = updated;
        },
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final chip = chips[index];
                  return Container(
                    padding: const EdgeInsets.only(
                        left: 12, right: 6, top: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: _C.bluePale,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chip.label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _C.blueDark,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: chip.onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: _C.blueDark.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 12, color: _C.blueDark),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClearAll,
              child: Text(
                'Clear',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.blueDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveChipData {
  const _ActiveChipData({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTER BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _FilterBottomSheet extends ConsumerStatefulWidget {
  const _FilterBottomSheet({required this.onReset});
  final VoidCallback onReset;

  @override
  ConsumerState<_FilterBottomSheet> createState() =>
      _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _roleInputController = TextEditingController();

  static const _allLanguages = [
    'English',
    'Hindi',
    'Telugu',
    'Tamil',
    'Kannada',
    'Malayalam',
  ];

  @override
  void initState() {
    super.initState();
    _locationController.text = ref.read(advancedLocationProvider);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _roleInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gender = ref.watch(advancedGenderProvider);
    final languages = ref.watch(advancedLanguagesProvider);
    final roles = ref.watch(advancedRolesProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _C.ink,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    widget.onReset();
                    _locationController.clear();
                  },
                  child: Text(
                    'Reset All',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.blueDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Filter form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GENDER
                  const _SectionLabel(text: 'Gender'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _FilterChip(
                        label: 'Male',
                        icon: Icons.male_rounded,
                        isSelected: gender == 'male',
                        onTap: () {
                          ref.read(advancedGenderProvider.notifier).state =
                              gender == 'male' ? null : 'male';
                          ref.read(currentPageProvider.notifier).state = 0;
                        },
                      ),
                      const SizedBox(width: 10),
                      _FilterChip(
                        label: 'Female',
                        icon: Icons.female_rounded,
                        isSelected: gender == 'female',
                        onTap: () {
                          ref.read(advancedGenderProvider.notifier).state =
                              gender == 'female' ? null : 'female';
                          ref.read(currentPageProvider.notifier).state = 0;
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // CURRENT LOCATION
                  const _SectionLabel(text: 'Current Location'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _locationController,
                      onChanged: (v) {
                        ref.read(advancedLocationProvider.notifier).state = v;
                        ref.read(currentPageProvider.notifier).state = 0;
                      },
                      style: GoogleFonts.inter(fontSize: 14, color: _C.ink),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_on_outlined,
                            size: 20, color: _C.inkSoft),
                        hintText: 'e.g. Hyderabad, Chennai, Mumbai',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // LANGUAGES KNOWN
                  const _SectionLabel(text: 'Languages Known'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allLanguages.map((lang) {
                      final isSelected = languages.contains(lang);
                      return _LanguageChip(
                        label: lang,
                        isSelected: isSelected,
                        onTap: () {
                          final updated = Set<String>.from(languages);
                          isSelected
                              ? updated.remove(lang)
                              : updated.add(lang);
                          ref.read(advancedLanguagesProvider.notifier).state =
                              updated;
                          ref.read(currentPageProvider.notifier).state = 0;
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),

                  // ROLES / TAGS
                  const _SectionLabel(text: 'Roles / Tags'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...roles.map((role) => _RoleChip(
                            label: role,
                            onRemove: () {
                              final updated = Set<String>.from(roles)
                                ..remove(role);
                              ref
                                  .read(advancedRolesProvider.notifier)
                                  .state = updated;
                              ref.read(currentPageProvider.notifier).state = 0;
                            },
                          )),
                      _AddRoleButton(
                        onTap: () {
                          _showAddRoleDialog();
                          ref.read(currentPageProvider.notifier).state = 0;
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Apply button
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 0, 24, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: AnimatedPressButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: _C.blue.withValues(alpha: 0.35),
                ),
                child: Text(
                  'Apply Filters',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRoleDialog() {
    _roleInputController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Role',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: _roleInputController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Police, Doctor, Villain',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: GoogleFonts.inter(color: _C.inkSoft)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _roleInputController.text.trim();
              if (text.isNotEmpty) {
                final updated =
                    Set<String>.from(ref.read(advancedRolesProvider));
                updated.add(text);
                ref.read(advancedRolesProvider.notifier).state = updated;
                ref.read(currentPageProvider.notifier).state = 0;
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.blue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORM SUB-COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _C.inkSoft,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _C.blue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _C.blue : _C.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _C.blue.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18,
                  color: isSelected ? Colors.white : _C.inkSoft),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : _C.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? _C.bluePale : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _C.blue : _C.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? _C.blue : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? _C.blue : const Color(0xFFD1D5DB),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _C.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 9, bottom: 9),
      decoration: BoxDecoration(
        color: _C.bluePale,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _C.blueDark,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _C.blueDark.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: _C.blueDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddRoleButton extends StatelessWidget {
  const _AddRoleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: const Color(0xFFD1D5DB), style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: _C.inkSoft),
            const SizedBox(width: 6),
            Text(
              'Add Role',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _C.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTOR CARD
// ═══════════════════════════════════════════════════════════════════════════════

class ActorCard extends StatelessWidget {
  const ActorCard({super.key, required this.actor});
  final ActorModel actor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.actorProfile}/${actor.id}', extra: actor),
      child: Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: actor.avatar != null && actor.avatar!.isNotEmpty
                    ? Hero(
                        tag: 'actor_avatar_${actor.id}',
                        child: CachedNetworkImage(
                          imageUrl: actor.avatar!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          maxWidthDiskCache: 600,
                          fadeInDuration: const Duration(milliseconds: 150),
                          placeholder: (context, url) =>
                              const ShimmerPlaceholder(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 0,
                          ),
                          errorWidget: (context, url, error) =>
                              const _PlaceholderImage(),
                        ),
                      )
                    : const _PlaceholderImage(),
              ),
            ),

            // Name + Wishlist
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      actor.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  WishlistHeartButton(actorId: actor.id, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLACEHOLDER IMAGE
// ═══════════════════════════════════════════════════════════════════════════════

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _C.chip,
      child: const Center(
        child: Icon(Icons.person, size: 44, color: Color(0xFF9CA3AF)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED LOADING GRID
// ═══════════════════════════════════════════════════════════════════════════════

Widget _buildLoadingGrid() {
  return CustomScrollView(
    slivers: [
      const SliverToBoxAdapter(
        child: AdvertisementBanner(),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => const ActorCardShimmer(),
            childCount: 6,
          ),
        ),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGINATION CONTROLS
// ═══════════════════════════════════════════════════════════════════════════════

class _PaginationControls extends ConsumerWidget {
  const _PaginationControls({required this.totalCountAsync});
  final AsyncValue<int> totalCountAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(currentPageProvider);
    final itemsPerPage = ref.watch(itemsPerPageProvider);

    return totalCountAsync.when(
      data: (totalCount) {
        final totalPages =
            (totalCount / itemsPerPage).ceil();
        final isFirstPage = currentPage == 0;
        final isLastPage = currentPage >= totalPages - 1;

        if (totalCount == 0) {
          return const SizedBox.shrink();
        }

        final startItem = currentPage * itemsPerPage + 1;
        final endItem = ((currentPage + 1) * itemsPerPage).clamp(0, totalCount);

        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _C.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info text
              Text(
                'Showing $startItem - $endItem of $totalCount',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _C.inkSoft,
                ),
              ),
              const SizedBox(height: 12),
              // Navigation buttons
              Row(
                children: [
                  // Previous button
                  Expanded(
                    child: GestureDetector(
                      onTap: isFirstPage
                          ? null
                          : () {
                              ref.read(currentPageProvider.notifier).state =
                                  currentPage - 1;
                              Scrollable.ensureVisible(
                                context,
                                alignment: 0.1,
                                duration: const Duration(milliseconds: 300),
                              );
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isFirstPage
                              ? const Color(0xFFEEEEEE)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFirstPage ? _C.border : _C.blue,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chevron_left_rounded,
                                size: 18,
                                color: isFirstPage ? Colors.grey : _C.blue),
                            const SizedBox(width: 4),
                            Text(
                              'Previous',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isFirstPage ? Colors.grey : _C.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Page info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _C.bluePale,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _C.blue),
                    ),
                    child: Text(
                      '${currentPage + 1} / ${totalPages.clamp(1, double.infinity).toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _C.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Next button
                  Expanded(
                    child: GestureDetector(
                      onTap: isLastPage
                          ? null
                          : () {
                              ref.read(currentPageProvider.notifier).state =
                                  currentPage + 1;
                              Scrollable.ensureVisible(
                                context,
                                alignment: 0.1,
                                duration: const Duration(milliseconds: 300),
                              );
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isLastPage
                              ? const Color(0xFFEEEEEE)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLastPage ? _C.border : _C.blue,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Next',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isLastPage ? Colors.grey : _C.blue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded,
                                size: 18,
                                color: isLastPage ? Colors.grey : _C.blue),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        child: const SizedBox(
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

