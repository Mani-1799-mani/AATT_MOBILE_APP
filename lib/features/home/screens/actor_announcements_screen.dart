import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:aatt/core/widgets/ui_helpers.dart';
import 'package:aatt/features/home/models/announcement_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS — extracted from Figma node 180:1835
// ═══════════════════════════════════════════════════════════════════════════════

class _Tok {
  _Tok._();

  // Colours
  static const blueRibbon = Color(0xFF0657F9);
  static const ebony = Color(0xFF111827);
  static const paleSky = Color(0xFF6B7280);
  static const grayChateau = Color(0xFF9CA3AF);
  static const athensGray = Color(0xFFF3F4F6);
  static const tabTrack = Color(0xFFE5E7EB);

  // Card shadow
  static final cardShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 7,
    offset: const Offset(0, 1.74),
  );

  // Typography (Inter family via GoogleFonts)
  static final headerStyle = GoogleFonts.inter(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    color: ebony,
    letterSpacing: -0.75,
  );

  static final tabActiveStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static final tabInactiveStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: paleSky,
  );

  static final cardTitleStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: ebony,
  );

  static final cardTagStyle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: paleSky,
  );

  static final cardTimeStyle = GoogleFonts.inter(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    color: grayChateau,
  );

  static final viewBtnStyle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: ebony,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTOR ANNOUNCEMENTS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class ActorAnnouncementsScreen extends StatefulWidget {
  const ActorAnnouncementsScreen({super.key});

  @override
  State<ActorAnnouncementsScreen> createState() =>
      _ActorAnnouncementsScreenState();
}

class _ActorAnnouncementsScreenState extends State<ActorAnnouncementsScreen> {
  /// 0 = Active, 1 = History
  int _tabIndex = 0;
  static const int _pageSize = 20;
  static const int _queryLimit = 21;

  final ScrollController _scrollController = ScrollController();

  List<AnnouncementDoc> _items = const [];
  DocumentSnapshot? _lastDoc;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _loadError;

  Query<Map<String, dynamic>> get _baseQuery {
    final collection = FirebaseFirestore.instance.collection('announcements');
    if (_tabIndex == 0) {
      // Active: approved/live posts, client-side filter handles start/expiry dates
      return collection
          .where('status', whereIn: ['APPROVED', 'ACTIVE'])
          .orderBy('submittedAt', descending: true);
    } else {
      // History: approved/live posts that later expired, plus explicitly expired posts
      return collection
          .where('status', whereIn: ['APPROVED', 'ACTIVE', 'EXPIRED'])
          .orderBy('submittedAt', descending: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _refreshTabData();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isInitialLoading || _isLoadingMore || !_hasMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _loadMore();
    }
  }

  Future<void> _onTabChanged(int index) async {
    if (_tabIndex == index) return;
    setState(() => _tabIndex = index);
    await _refreshTabData();
  }

  Future<void> _refreshTabData() async {
    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _lastDoc = null;
      _items = const [];
      _loadError = null;
    });
    await _fetchPage(isInitial: true);
  }

  Future<void> _loadMore() async {
    if (_isInitialLoading || _isLoadingMore || !_hasMore) return;
    await _fetchPage(isInitial: false);
  }

  Future<void> _fetchPage({required bool isInitial}) async {
    if (!mounted) return;

    setState(() {
      if (isInitial) {
        _loadError = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      Query<Map<String, dynamic>> query = _baseQuery.limit(_queryLimit);
      if (!isInitial && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      if (isInitial) {
        try {
          final cachedSnapshot = await query.get(const GetOptions(source: Source.cache));
          if (cachedSnapshot.docs.isNotEmpty) {
            _applySnapshotDocs(cachedSnapshot.docs, isInitial: true);
          }
        } catch (_) {
          // Ignore cache miss and continue with network fetch.
        }
      }

      final snapshot = await query.get();
      _applySnapshotDocs(snapshot.docs, isInitial: isInitial);
    } catch (error) {
      debugPrint('Announcements fetch error: $error');
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _applySnapshotDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool isInitial,
  }) {
    final hasMore = docs.length > _pageSize;
    final docsPage = hasMore ? docs.take(_pageSize).toList() : docs;

    final parsed = <AnnouncementDoc>[];
    for (final doc in docsPage) {
      try {
        parsed.add(AnnouncementDoc.fromFirestore(doc));
      } catch (e) {
        debugPrint('Skipping malformed announcement ${doc.id}: $e');
      }
    }

    List<AnnouncementDoc> filtered;
    if (_tabIndex == 0) {
      filtered = parsed
          .where((item) =>
              item.status == AnnouncementStatus.approved &&
              item.isCurrentlyActive)
          .toList();
    } else {
      filtered = parsed
          .where((item) =>
              item.status == AnnouncementStatus.expired || item.isExpired)
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _items = isInitial ? filtered : [..._items, ...filtered];
      _lastDoc = docsPage.isNotEmpty ? docsPage.last : _lastDoc;
      _hasMore = hasMore;
      _isInitialLoading = false;
      _isLoadingMore = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back + Header ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: _Tok.ebony),
                    ),
                  ),
                  Text('Announcements', style: _Tok.headerStyle),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Tab Toggle ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TabToggle(
                selectedIndex: _tabIndex,
                onChanged: _onTabChanged,
              ),
            ),

            const SizedBox(height: 20),

            // ── Announcement List ────────────────────────────
            Expanded(
              child: _buildAnnouncementsBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsBody() {
    if (_isInitialLoading) {
      return _buildShimmerList();
    }

    if (_loadError != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: _Tok.grayChateau),
              const SizedBox(height: 12),
              Text('Something went wrong', style: _Tok.cardTitleStyle),
              const SizedBox(height: 8),
              Text(
                '$_loadError',
                style: _Tok.cardTagStyle,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _refreshTabData,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: _Tok.blueRibbon,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: EmptyStateWidget(
          icon: Icons.campaign_outlined,
          title: _tabIndex == 0
              ? 'No active announcements'
              : 'No past announcements',
          subtitle: _tabIndex == 0
              ? 'Check back later for new updates'
              : 'Past announcements will appear here',
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _AnnouncementCard(announcement: _items[i]);
      },
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (_, index) => const AnnouncementCardShimmer(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB TOGGLE  — Active / History pill switch
// ═══════════════════════════════════════════════════════════════════════════════

class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: _Tok.tabTrack,
        borderRadius: BorderRadius.circular(21),
      ),
      padding: const EdgeInsets.all(3.5),
      child: Row(
        children: [
          _buildTab('Active', 0),
          _buildTab('History', 1),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isActive ? _Tok.blueRibbon : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: isActive ? _Tok.tabActiveStyle : _Tok.tabInactiveStyle,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANNOUNCEMENT CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});
  final AnnouncementDoc announcement;

  @override
  Widget build(BuildContext context) {
    final tagLine = announcement.tags.map((t) => t.label).join('  •  ');
    final ago = timeago.format(announcement.submittedAt);

    return GestureDetector(
      onTap: () => context.push('/announcement-detail', extra: announcement),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [_Tok.cardShadow],
          border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        ),
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            // ── Text column ─────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'announcement_title_${announcement.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        announcement.title,
                        style: _Tok.cardTitleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (tagLine.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(tagLine, style: _Tok.cardTagStyle, maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Text(ago, style: _Tok.cardTimeStyle),
                  const SizedBox(height: 12),
                  _ViewButton(onTap: () {
                    context.push('/announcement-detail', extra: announcement);
                  }),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ── Thumbnail or Avatar ──
            Hero(
              tag: 'announcement_avatar_${announcement.id}',
              child: announcement.thumbnailUrl != null &&
                      announcement.thumbnailUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: announcement.thumbnailUrl!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: _Tok.athensGray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _SubmitterAvatar(url: announcement.submitterAvatar),
                      ),
                    )
                  : _SubmitterAvatar(url: announcement.submitterAvatar),
            ),
          ],
        ),
      ),
    );
  }
}

// ── View Button ──────────────────────────────────────────────────────────────

class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 32,
        decoration: BoxDecoration(
          color: _Tok.athensGray,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text('View', style: _Tok.viewBtnStyle),
      ),
    );
  }
}

// ── Submitter Avatar ─────────────────────────────────────────────────────────

class _SubmitterAvatar extends StatelessWidget {
  const _SubmitterAvatar({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = 70.0;
    const radius = 28.0;

    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, progress) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _Tok.athensGray,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          errorWidget: (_, errorUrl, error) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: _Tok.athensGray,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Icon(Icons.person, size: 34, color: _Tok.grayChateau),
    );
  }
}
