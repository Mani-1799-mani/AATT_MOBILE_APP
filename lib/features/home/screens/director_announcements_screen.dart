import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:aatt/core/widgets/ui_helpers.dart';
import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/home/models/announcement_model.dart';
import 'package:aatt/features/home/providers/director_announcements_controller.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS — extracted from Figma node 223:16048 / 223:16243 / 223:16363
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

  // Orange palette (Under Review)
  static const tiaMaria = Color(0xFFC2410C);
  static const christine = Color(0xFFEA580C);
  static const papayaWhip = Color(0xFFFFEDD5);
  static const navajoWhite = Color(0xFFFED7AA);

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
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static final tabInactiveStyle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: paleSky,
  );

  static final cardTitleStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: ebony,
  );

  static final cardDescStyle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: paleSky,
  );

  static final cardTimeStyle = GoogleFonts.inter(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    color: grayChateau,
  );

  static final newBtnTextStyle = GoogleFonts.inter(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static final pendingBadgeStyle = GoogleFonts.inter(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: tiaMaria,
  );

  static final waitingAdminStyle = GoogleFonts.inter(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    color: christine,
  );

  static final closedBadgeStyle = GoogleFonts.inter(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: paleSky,
  );

  static final repostBtnStyle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: blueRibbon,
  );

  static final expiredTimeStyle = GoogleFonts.inter(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    color: grayChateau,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIRECTOR ANNOUNCEMENTS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class DirectorAnnouncementsScreen extends ConsumerStatefulWidget {
  const DirectorAnnouncementsScreen({super.key});

  @override
  ConsumerState<DirectorAnnouncementsScreen> createState() =>
      _DirectorAnnouncementsScreenState();
}

class _DirectorAnnouncementsScreenState
    extends ConsumerState<DirectorAnnouncementsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final uid = ref.read(authControllerProvider).uid ?? '';
    if (uid.isEmpty) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 220) {
      ref.read(directorAnnouncementsProvider(uid).notifier).loadMore();
    }
  }

  void _onTabChanged(int index) {
    final uid = ref.read(authControllerProvider).uid ?? '';
    if (uid.isEmpty) return;
    ref.read(directorAnnouncementsProvider(uid).notifier).changeTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final uid = authState.uid ?? '';

    if (uid.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final state = ref.watch(directorAnnouncementsProvider(uid));
    final controller = ref.read(directorAnnouncementsProvider(uid).notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('My Announcements', style: _Tok.headerStyle),
                  ),
                  _NewButton(
                    onTap: () => context.push('/director-create-announcement'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Tab Toggle ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _ThreeTabToggle(
                selectedIndex: controller.tabIndex,
                onChanged: _onTabChanged,
              ),
            ),

            const SizedBox(height: 16),

            // ── Announcement List ────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: _Tok.blueRibbon,
                onRefresh: () => controller.refresh(),
                child: _buildBody(state, controller),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      DirectorAnnouncementsState state, DirectorAnnouncementsController ctrl) {
    if (state.isInitialLoading) {
      return _buildShimmerList();
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Failed to load announcements.\n${state.error}',
            textAlign: TextAlign.center,
            style: _Tok.cardDescStyle,
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      final tabIdx = ctrl.tabIndex;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          EmptyStateWidget(
            icon: Icons.campaign_outlined,
            title: tabIdx == 0
                ? 'No active announcements'
                : tabIdx == 1
                    ? 'Nothing under review'
                    : 'No expired announcements',
            subtitle: tabIdx == 0
                ? 'Create your first announcement to get started'
                : tabIdx == 1
                    ? 'Your pending submissions will appear here'
                    : 'Expired announcements will show up here',
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= state.items.length) {
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _DirectorAnnouncementCard(
            announcement: state.items[i],
            tabIndex: ctrl.tabIndex,
            onEdit: () => context.push(
              '/director-announcement-detail',
              extra: state.items[i],
            ),
            onClose: () => _confirmClose(state.items[i], ctrl),
            onRepost: () => _confirmRepost(state.items[i], ctrl),
          ),
        );
      },
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: 4,
      itemBuilder: (ctx, idx) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: AnnouncementCardShimmer(),
      ),
    );
  }

  // ── Confirm Close ──

  void _confirmClose(
      AnnouncementDoc announcement, DirectorAnnouncementsController ctrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _Tok.tabTrack,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Close Announcement?',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _Tok.ebony,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will mark "${announcement.title}" as expired. Actors will no longer see it.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _Tok.paleSky,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: _Tok.tabTrack),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _Tok.ebony,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ctrl.closeAnnouncement(announcement.id);
                      if (mounted) {
                        showPremiumSnackbar(context, 'Announcement closed');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Close',
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
          ],
        ),
      ),
    );
  }

  // ── Confirm Repost ──

  void _confirmRepost(
      AnnouncementDoc announcement, DirectorAnnouncementsController ctrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _Tok.tabTrack,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Repost Announcement?',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _Tok.ebony,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${announcement.title}" will be resubmitted for admin review.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _Tok.paleSky,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: _Tok.tabTrack),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _Tok.ebony,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ctrl.repostAnnouncement(announcement.id);
                      if (mounted) {
                        showPremiumSnackbar(context, 'Announcement resubmitted for review');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Tok.blueRibbon,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Repost',
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
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// + NEW BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class _NewButton extends StatelessWidget {
  const _NewButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 30,
        decoration: BoxDecoration(
          color: _Tok.blueRibbon,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 1.74,
              offset: const Offset(0, 0.87),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 14),
            const SizedBox(width: 3),
            Text('New', style: _Tok.newBtnTextStyle),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// THREE-TAB TOGGLE — Active / Under Review / Expired
// ═══════════════════════════════════════════════════════════════════════════════

class _ThreeTabToggle extends StatelessWidget {
  const _ThreeTabToggle({required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: _Tok.tabTrack,
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.all(3.5),
      child: Row(
        children: List.generate(3, (i) => _buildTab(DirectorAnnouncementsController.tabLabels[i], i)),
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
            borderRadius: BorderRadius.circular(100),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 1.74,
                      offset: const Offset(0, 0.87),
                    ),
                  ]
                : null,
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
// DIRECTOR ANNOUNCEMENT CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _DirectorAnnouncementCard extends StatelessWidget {
  const _DirectorAnnouncementCard({
    required this.announcement,
    required this.tabIndex,
    required this.onEdit,
    required this.onClose,
    required this.onRepost,
  });

  final AnnouncementDoc announcement;
  final int tabIndex;
  final VoidCallback onEdit;
  final VoidCallback onClose;
  final VoidCallback onRepost;

  @override
  Widget build(BuildContext context) {
    final mediaUrls = announcement.mediaUrls;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [_Tok.cardShadow],
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.0),
            width: 0.87,
          ),
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SubmitterAvatar(url: announcement.submitterAvatar),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.submitterName.isNotEmpty
                            ? announcement.submitterName
                            : 'Director',
                        style: _Tok.cardTitleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Posted ${timeago.format(announcement.submittedAt)}',
                        style: _Tok.cardTimeStyle,
                      ),
                    ],
                  ),
                ),
                if (tabIndex == 1) _PendingBadgeRow(),
                if (tabIndex == 2) _ClosedBadgeRow(announcement: announcement),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              announcement.title,
              style: _Tok.cardTitleStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            if (announcement.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                announcement.description,
                style: _Tok.cardDescStyle,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            if (mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: mediaUrls.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: mediaUrls[index],
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 120,
                        height: 120,
                        color: _Tok.athensGray,
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 120,
                        height: 120,
                        color: _Tok.athensGray,
                        child: const Icon(Icons.broken_image,
                            color: _Tok.grayChateau),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Divider + Actions ──
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: _Tok.athensGray, width: 0.87),
                ),
              ),
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  // ── Time ──
                  Text(
                    'Status: ${announcement.status.value}',
                    style: _Tok.cardTimeStyle,
                  ),
                  const Spacer(),
                  // ── Action Buttons ──
                  ..._buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    switch (tabIndex) {
      case 0: // Active — Edit + Close
        return [
          _ActionButton(
            label: 'Edit',
            icon: Icons.edit_outlined,
            backgroundColor: _Tok.blueRibbon,
            textColor: Colors.white,
            onTap: onEdit,
          ),
          const SizedBox(width: 12),
          _ActionButton(
            label: 'Close',
            backgroundColor: _Tok.athensGray,
            textColor: _Tok.ebony,
            onTap: onClose,
          ),
        ];
      case 1: // Under Review — Edit (gray)
        return [
          _ActionButton(
            label: 'Edit',
            icon: Icons.edit_outlined,
            backgroundColor: _Tok.athensGray,
            textColor: _Tok.ebony,
            onTap: onEdit,
          ),
        ];
      case 2: // Expired — Repost
        return [
          _RepostButton(onTap: onRepost),
        ];
      default:
        return [];
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS BADGE ROWS
// ═══════════════════════════════════════════════════════════════════════════════

class _PendingBadgeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _Tok.papayaWhip,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _Tok.navajoWhite, width: 0.87),
          ),
          child: Text('Pending', style: _Tok.pendingBadgeStyle),
        ),
        const SizedBox(width: 7),
        Text('Waiting for Admin', style: _Tok.waitingAdminStyle),
      ],
    );
  }
}

class _ClosedBadgeRow extends StatelessWidget {
  const _ClosedBadgeRow({required this.announcement});
  final AnnouncementDoc announcement;

  @override
  Widget build(BuildContext context) {
    final isRejected = announcement.status == AnnouncementStatus.rejected;
    String expiredText = '';
    if (announcement.expiresAt != null) {
      expiredText = 'Expired ${timeago.format(announcement.expiresAt!)}';
    } else if (announcement.reviewedAt != null) {
      expiredText = isRejected
          ? 'Reviewed ${timeago.format(announcement.reviewedAt!)}'
          : 'Expired ${timeago.format(announcement.reviewedAt!)}';
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _Tok.athensGray,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _Tok.tabTrack, width: 0.87),
          ),
          child: Text(
            isRejected ? 'Rejected' : 'Expired',
            style: _Tok.closedBadgeStyle,
          ),
        ),
        if (expiredText.isNotEmpty) ...[
          const SizedBox(width: 7),
          Text(expiredText, style: _Tok.expiredTimeStyle),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 30,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepostButton extends StatelessWidget {
  const _RepostButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh_rounded, size: 16, color: _Tok.blueRibbon),
          const SizedBox(width: 4),
          Text('Repost', style: _Tok.repostBtnStyle),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUBMITTER AVATAR
// ═══════════════════════════════════════════════════════════════════════════════

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
          placeholder: (ctx, url) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _Tok.athensGray,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          errorWidget: (ctx, url, err) => _fallback(),
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
