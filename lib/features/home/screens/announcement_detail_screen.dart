import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:aatt/features/home/models/announcement_model.dart';

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
    color: const Color(0xFF374151),
    height: 1.6,
  );

  static final tagStyle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: blueRibbon,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANNOUNCEMENT DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.announcement});

  final AnnouncementDoc announcement;

  @override
  Widget build(BuildContext context) {
    final ago = timeago.format(announcement.submittedAt);
    final isExpired = announcement.isExpired || announcement.status == AnnouncementStatus.expired;
    final mediaUrls = announcement.mediaUrls;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _Tok.ebony),
          onPressed: () => context.pop(),
        ),
        title: Text('Announcement', style: _Tok.headerStyle),
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
                  tag: 'announcement_avatar_${announcement.id}',
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
                          Icon(Icons.access_time_rounded, size: 14, color: _Tok.grayChateau),
                          const SizedBox(width: 4),
                          Text(ago, style: _Tok.timeStyle),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isExpired ? _Tok.errorRed.withValues(alpha: 0.1) : _Tok.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isExpired ? 'Expired' : 'Active',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isExpired ? _Tok.errorRed : _Tok.successGreen,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Title ────────────────────────────────────────────────────────
            Hero(
              tag: 'announcement_title_${announcement.id}',
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _Tok.blueRibbon.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _Tok.blueRibbon.withValues(alpha: 0.2)),
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
              announcement.description,
              style: _Tok.descriptionStyle,
            ),

            // ── Schedule ─────────────────────────────────────────────────────
            if (announcement.startsAt != null ||
                announcement.expiresAt != null) ...[
              const SizedBox(height: 24),
              const Divider(color: _Tok.athensGray, thickness: 1.5),
              const SizedBox(height: 24),
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

            const SizedBox(height: 40),
          ],
        ),
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
