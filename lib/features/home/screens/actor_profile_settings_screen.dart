import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aatt/core/router/app_router.dart';
import 'package:aatt/core/widgets/ui_helpers.dart';
import 'package:aatt/core/services/actor_profile_update_api.dart';
import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/home/models/actor_model.dart';
import 'package:aatt/features/home/providers/actor_profile_provider.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────
class _Tok {
  _Tok._();
  static const blueRibbon = Color(0xFF0657F9);
  static const vulcan = Color(0xFF0D121C);
  static const paleSky = Color(0xFF6B7280);
  static const athensGray = Color(0xFFF3F4F6);
  static const flamingo = Color(0xFFEF4444);
  static const white = Colors.white;
  static const lighter = Color(0xFF939393);
  static const blueLight = Color(0xFFD9E8F7);
  static const bluePale = Color(0xFFEFF6FF);
}

/// Actor Profile & Settings screen.
class ActorProfileSettingsScreen extends ConsumerWidget {
  const ActorProfileSettingsScreen({super.key});

  static final Uri _supportEmailUri = Uri(
    scheme: 'mailto',
    path: 'support@aatt.app',
    queryParameters: {
      'subject': 'AATT Actor App Support',
    },
  );

  static final Uri _privacyPolicyUri =
      Uri.parse('https://aatt.app/privacy-policy');

  Future<void> _openSupport(BuildContext context) async {
    if (await canLaunchUrl(_supportEmailUri)) {
      await launchUrl(_supportEmailUri, mode: LaunchMode.externalApplication);
      return;
    }

    if (context.mounted) {
      showPremiumSnackbar(
        context,
        'Unable to open email app. Contact: support@aatt.app',
        isError: true,
      );
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    if (await canLaunchUrl(_privacyPolicyUri)) {
      await launchUrl(_privacyPolicyUri, mode: LaunchMode.externalApplication);
      return;
    }

    if (context.mounted) {
      showPremiumSnackbar(
        context,
        'Unable to open privacy policy at the moment.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentActorProfileProvider);
    final historyAsync = ref.watch(actorProfileUpdateHistoryProvider);

    return Scaffold(
      backgroundColor: _Tok.white,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading profile: $e')),
        data: (actor) {
          if (actor == null) {
            return const Center(child: Text('Profile not found'));
          }

          final name = actor.name;
          final avatarUrl = actor.avatar;

          return CustomScrollView(
            slivers: [
              // ── Gradient Header with Avatar ─────────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_Tok.blueLight, _Tok.white],
                      stops: [0.5, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // App Bar
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 8, top: 8, bottom: 8, right: 16),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.pop(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.chevron_left_rounded,
                                      size: 28, color: _Tok.vulcan),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Profile & Settings',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: _Tok.vulcan,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(width: 44),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Avatar
                        _AvatarWithBadge(
                          avatarUrl: avatarUrl,
                          onTap: () =>
                              context.push(AppRoutes.actorProfileUpdate),
                        ),
                        const SizedBox(height: 16),

                        // Name
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _Tok.vulcan,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: _Tok.bluePale,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Actor',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _Tok.blueRibbon,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Settings Content ────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // My Account
                    _SectionHeader(label: 'MY ACCOUNT'),
                    const SizedBox(height: 10),
                    _ProfileSummaryCard(actor: actor),
                    const SizedBox(height: 12),
                    _ProfileUpdateRequestCard(historyAsync: historyAsync),
                    const SizedBox(height: 16),
                    _SettingsGroup(
                      children: [
                        _SettingsTile(
                          icon: Icons.person_outline_rounded,
                          label: 'Personal Details',
                          subtitle: 'Request profile changes for admin review',
                          onTap: () =>
                              context.push(AppRoutes.actorProfileUpdate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Support & Legal
                    _SectionHeader(label: 'SUPPORT & LEGAL'),
                    const SizedBox(height: 10),
                    _SettingsGroup(
                      children: [
                        _SettingsTile(
                          icon: Icons.help_outline_rounded,
                          label: 'Help & Support',
                          subtitle: 'Get help with your account',
                          onTap: () => _openSupport(context),
                          showDivider: true,
                        ),
                        _SettingsTile(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Privacy Policy',
                          subtitle: 'Read our privacy policy',
                          onTap: () => _openPrivacyPolicy(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Log Out
                    _LogOutButton(
                      onTap: () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
                        if (context.mounted) {
                          context.go(AppRoutes.login);
                        }
                      },
                    ),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileUpdateRequestCard extends StatelessWidget {
  const _ProfileUpdateRequestCard({required this.historyAsync});

  final AsyncValue<List<ActorProfileUpdateRequestItem>> historyAsync;

  @override
  Widget build(BuildContext context) {
    return historyAsync.when(
      loading: () => _ProfileUpdateCardShell(
        title: 'Profile review status',
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Checking your latest request status...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _Tok.paleSky,
                ),
              ),
            ),
          ],
        ),
      ),
      error: (error, _) => _ProfileUpdateCardShell(
        title: 'Profile review status',
        child: Text(
          'Unable to load request status: $error',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _Tok.flamingo,
            height: 1.4,
          ),
        ),
      ),
      data: (items) {
        final latest = _latestRequest(items);
        if (latest == null) {
          return _ProfileUpdateCardShell(
            title: 'Profile review status',
            child: Text(
              'No profile change requests found yet.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _Tok.paleSky,
              ),
            ),
          );
        }

        return _ProfileUpdateCardShell(
          title: 'Profile review status',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(status: latest.status),
                  const Spacer(),
                  Text(
                    _formatRequestDate(latest.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _Tok.paleSky,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                latest.title.isNotEmpty ? latest.title : 'Profile update request',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _Tok.vulcan,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                latest.description.isNotEmpty
                    ? latest.description
                    : 'Your latest profile changes are waiting for admin review.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _Tok.paleSky,
                  height: 1.45,
                ),
              ),
              if (latest.requestedUpdates.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Updated fields: ${latest.requestedUpdates.keys.join(', ')}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _Tok.blueRibbon,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  ActorProfileUpdateRequestItem? _latestRequest(
    List<ActorProfileUpdateRequestItem> items,
  ) {
    if (items.isEmpty) return null;

    final sorted = [...items]
      ..sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

    return sorted.first;
  }

  String _formatRequestDate(DateTime? createdAt) {
    if (createdAt == null) return 'Unknown date';
    final local = createdAt.toLocal();
    final month = _monthLabel(local.month);
    return '$month ${local.day}, ${local.year}';
  }

  String _monthLabel(int month) {
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > labels.length) return 'Unknown';
    return labels[month - 1];
  }
}

class _ProfileUpdateCardShell extends StatelessWidget {
  const _ProfileUpdateCardShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Tok.bluePale,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tok.blueLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _Tok.blueRibbon,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();
    final isApproved = normalized == 'APPROVED';
    final isRejected = normalized == 'REJECTED';
    final backgroundColor = isApproved
        ? const Color(0xFFDCFCE7)
        : isRejected
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFDBEAFE);
    final textColor = isApproved
        ? const Color(0xFF166534)
        : isRejected
            ? const Color(0xFFB91C1C)
            : _Tok.blueRibbon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized.isEmpty ? 'PENDING' : normalized,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.actor});

  final ActorModel actor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Tok.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tok.athensGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _ProfileInfoRow(label: 'Phone', value: actor.phone),
          _ProfileInfoRow(label: 'Email', value: actor.email),
          _ProfileInfoRow(label: 'Location', value: actor.location),
          _ProfileInfoRow(label: 'Height', value: actor.height),
          _ProfileInfoRow(
            label: 'Roles',
            value: (actor.rolesActed ?? const []).join(', '),
          ),
          _ProfileInfoRow(label: 'About', value: actor.about, isLast: true),
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String? value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final displayValue = value != null && value!.trim().isNotEmpty
        ? value!.trim()
        : 'Not provided';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: _Tok.athensGray),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _Tok.paleSky,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _Tok.vulcan,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar with blue edit badge ────────────────────────────────────────────

class _AvatarWithBadge extends StatelessWidget {
  const _AvatarWithBadge({this.avatarUrl, required this.onTap});

  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _Tok.blueRibbon.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Avatar circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _Tok.athensGray,
                border: Border.all(color: _Tok.white, width: 4),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      maxWidthDiskCache: 600,
                      fadeInDuration: const Duration(milliseconds: 150),
                      placeholder: (context, url) => const Icon(
                          Icons.person,
                          size: 48,
                          color: _Tok.lighter),
                      errorWidget: (context, url, error) => const Icon(
                          Icons.person,
                          size: 48,
                          color: _Tok.lighter),
                    )
                  : const Icon(Icons.person, size: 48, color: _Tok.lighter),
            ),

            // Edit badge
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _Tok.blueRibbon,
                  shape: BoxShape.circle,
                  border: Border.all(color: _Tok.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _Tok.blueRibbon.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.edit, size: 14, color: _Tok.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _Tok.paleSky,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Settings Group (rounded card) ──────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Tok.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tok.athensGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

// ─── Settings Tile ──────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.showDivider = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon circle
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _Tok.bluePale,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: _Tok.blueRibbon),
                ),
                const SizedBox(width: 14),
                // Label + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _Tok.vulcan,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: _Tok.paleSky,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Chevron
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _Tok.athensGray,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      size: 20, color: _Tok.paleSky),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 72),
            child: Divider(
                height: 1, thickness: 1, color: _Tok.athensGray),
          ),
      ],
    );
  }
}

// ─── Log Out Button ──────────────────────────────────────────────────────────

class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.logout_rounded,
            color: _Tok.flamingo, size: 20),
        label: Text(
          'Log Out',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _Tok.flamingo,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: _Tok.flamingo.withValues(alpha: 0.3), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: const Color(0xFFFEF2F2),
        ),
      ),
    );
  }
}
