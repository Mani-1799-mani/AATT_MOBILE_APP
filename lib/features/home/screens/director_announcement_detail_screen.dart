import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:aatt/core/widgets/ui_helpers.dart';
import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/home/models/announcement_model.dart';
import 'package:aatt/features/home/providers/director_announcements_controller.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════════════════════

class _Tok {
  _Tok._();

  // Colours
  static const blueRibbon = Color(0xFF0657F9);
  static const ebony = Color(0xFF111827);
  static const paleSky = Color(0xFF6B7280);
  static const grayChateau = Color(0xFF9CA3AF);
  static const athensGray = Color(0xFFF3F4F6);
  static const successGreen = Color(0xFF10B981);
  static const errorRed = Color(0xFFEF4444);
  static const oxfordBlue = Color(0xFF374151);
  static const tabTrack = Color(0xFFE5E7EB);

  // Orange palette (Under Review)
  static const tiaMaria = Color(0xFFC2410C);
  static const papayaWhip = Color(0xFFFFEDD5);

  // Typography
  static final headerStyle = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: ebony,
    letterSpacing: -0.5,
  );

  static final titleStyle = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: ebony,
    height: 1.3,
  );

  static final nameStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: ebony,
  );

  static final timeStyle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: grayChateau,
  );

  static final descriptionStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: oxfordBlue,
    height: 1.6,
  );

  static final tagStyle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: blueRibbon,
  );

  static final sectionLabel = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: paleSky,
    letterSpacing: 0.5,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIRECTOR ANNOUNCEMENT DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class DirectorAnnouncementDetailScreen extends ConsumerWidget {
  const DirectorAnnouncementDetailScreen({
    super.key,
    required this.announcement,
  });

  final AnnouncementDoc announcement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ago = timeago.format(announcement.submittedAt);
    final mediaUrls = announcement.mediaUrls;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: _Tok.ebony),
          onPressed: () => context.pop(),
        ),
        title: Text('Announcement', style: _Tok.headerStyle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                size: 22, color: _Tok.ebony),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _onEdit(context);
              } else if (value == 'delete') {
                _confirmDelete(context, ref);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined,
                        size: 18, color: _Tok.ebony),
                    const SizedBox(width: 10),
                    Text(
                      'Edit',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _Tok.ebony,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded,
                        size: 18, color: _Tok.errorRed),
                    const SizedBox(width: 10),
                    Text(
                      'Delete',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _Tok.errorRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Submitter Info ───────────────────────────────────────────────
            Row(
              children: [
                Hero(
                  tag: 'dir_announcement_avatar_${announcement.id}',
                  child: _SubmitterAvatar(url: announcement.submitterAvatar),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.submitterName.isNotEmpty
                            ? announcement.submitterName
                            : 'Unknown Submitter',
                        style: _Tok.nameStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 14, color: _Tok.grayChateau),
                          const SizedBox(width: 4),
                          Text(ago, style: _Tok.timeStyle),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge
                _StatusBadge(announcement: announcement),
              ],
            ),

            const SizedBox(height: 32),

            // ── Title ────────────────────────────────────────────────────────
            Hero(
              tag: 'dir_announcement_title_${announcement.id}',
              child: Material(
                color: Colors.transparent,
                child: Text(
                  announcement.title,
                  style: _Tok.titleStyle,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Tags ─────────────────────────────────────────────────────────
            if (announcement.tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: announcement.tags.map((tag) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _Tok.blueRibbon.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _Tok.blueRibbon.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(tag.label, style: _Tok.tagStyle),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            const Divider(color: _Tok.athensGray, thickness: 1.5),
            const SizedBox(height: 24),

            // ── Media ─────────────────────────────────────────────────────
            if (mediaUrls.isNotEmpty) ...[
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: mediaUrls.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: mediaUrls[index],
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 220,
                        height: 220,
                        color: _Tok.athensGray,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 220,
                        height: 220,
                        color: _Tok.athensGray,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Description ──────────────────────────────────────────────────
            Text(
              'DESCRIPTION',
              style: _Tok.sectionLabel,
            ),
            const SizedBox(height: 12),
            Text(
              announcement.description,
              style: _Tok.descriptionStyle,
            ),

            // ── Schedule ─────────────────────────────────────────────────────
            if (announcement.startsAt != null ||
                announcement.expiresAt != null) ...[
              const SizedBox(height: 24),
              const Divider(color: _Tok.athensGray, thickness: 1.5),
              const SizedBox(height: 24),
              Text('SCHEDULE', style: _Tok.sectionLabel),
              const SizedBox(height: 12),
              if (announcement.startsAt != null) ...[
                Row(
                  children: [
                    const Icon(Icons.play_circle_outline_rounded,
                        size: 18, color: _Tok.paleSky),
                    const SizedBox(width: 8),
                    Text(
                      'Starts: ${DateFormat('MMM dd, yyyy').format(announcement.startsAt!)}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _Tok.ebony,
                      ),
                    ),
                  ],
                ),
                if (announcement.expiresAt != null)
                  const SizedBox(height: 12),
              ],
              if (announcement.expiresAt != null)
                Row(
                  children: [
                    const Icon(Icons.event_outlined,
                        size: 18, color: _Tok.paleSky),
                    const SizedBox(width: 8),
                    Text(
                      'Ends: ${DateFormat('MMM dd, yyyy').format(announcement.expiresAt!)}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _Tok.ebony,
                      ),
                    ),
                  ],
                ),
            ],

            const SizedBox(height: 48),

            // ── Action Buttons ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _onEdit(context),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(
                        'Edit',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Tok.blueRibbon,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context, ref),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: _Tok.errorRed),
                      label: Text(
                        'Delete',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _Tok.errorRed,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: _Tok.errorRed),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _onEdit(BuildContext context) {
    context.push('/director-create-announcement', extra: announcement);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _Tok.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 28,
                color: _Tok.errorRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Announcement?',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _Tok.ebony,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone. "${announcement.title}" will be permanently removed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _Tok.paleSky,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final uid =
                            ref.read(authControllerProvider).uid ?? '';
                        await ref
                            .read(directorAnnouncementsProvider(uid).notifier)
                            .deleteAnnouncement(announcement.id);
                        if (context.mounted) {
                          showPremiumSnackbar(
                              context, 'Announcement deleted');
                          context.pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Tok.errorRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
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
// STATUS BADGE
// ═══════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.announcement});
  final AnnouncementDoc announcement;

  @override
  Widget build(BuildContext context) {
    final status = announcement.status;
    final isExpired = announcement.isExpired ||
        status == AnnouncementStatus.expired;
    final isReview = status == AnnouncementStatus.review;
    final isRejected = status == AnnouncementStatus.rejected;

    Color bg;
    Color fg;
    String label;

    if (isExpired || isRejected) {
      bg = _Tok.errorRed.withValues(alpha: 0.1);
      fg = _Tok.errorRed;
      label = isRejected ? 'Rejected' : 'Expired';
    } else if (isReview) {
      bg = _Tok.papayaWhip;
      fg = _Tok.tiaMaria;
      label = 'Under Review';
    } else {
      bg = _Tok.successGreen.withValues(alpha: 0.1);
      fg = _Tok.successGreen;
      label = 'Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
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
    const size = 56.0;
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
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _Tok.athensGray,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Icon(Icons.person, size: 28, color: _Tok.grayChateau),
    );
  }
}
