import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:aatt/core/widgets/ui_helpers.dart';
import 'package:aatt/features/home/models/actor_model.dart';
import 'package:aatt/features/home/widgets/wishlist_heart_button.dart';
import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/auth/models/auth_state.dart';
import 'package:aatt/features/auth/providers/director_providers.dart';
import 'package:aatt/features/home/providers/actor_profile_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const String kAattFullName = 'Artistes Association of Telugu Television';

// ─── Design Tokens ──────────────────────────────────────────────────────────
class _K {
  _K._();
  static const blue = Color(0xFF1652F0);
  static const bluePale = Color(0xFFEFF6FF);
  static const ink = Color(0xFF1D1C31);
  static const inkSoft = Color(0xFF64748B);
  static const border = Color(0xFFE5E7EB);
  static const chip = Color(0xFFF3F4F6);
  static const chipText = Color(0xFF374151);
}

class ActorProfileRouteScreen extends ConsumerWidget {
  const ActorProfileRouteScreen({
    super.key,
    required this.actorId,
    this.initialActor,
  });

  final String actorId;
  final ActorModel? initialActor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = initialActor;
    if (actor != null) {
      return ActorProfileScreen(actor: actor);
    }

    final actorAsync = ref.watch(actorProfileProvider(actorId));
    return actorAsync.when(
      data: (loadedActor) {
        if (loadedActor == null) {
          return const Scaffold(
            body: EmptyStateWidget(
              icon: Icons.person_off_outlined,
              title: 'Actor not found',
              subtitle: 'This profile is unavailable.',
            ),
          );
        }
        return ActorProfileScreen(actor: loadedActor);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load actor profile.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class ActorProfileScreen extends ConsumerStatefulWidget {
  const ActorProfileScreen({super.key, required this.actor});

  final ActorModel actor;

  @override
  ConsumerState<ActorProfileScreen> createState() => _ActorProfileScreenState();
}

class _ActorProfileScreenState extends ConsumerState<ActorProfileScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.72);
  bool _aboutExpanded = false;
  int _selectedTab = 0;
  bool _isSendingSms = false;

  // Keys for scroll-to-section
  final _serialsKey = GlobalKey();
  final _moviesKey = GlobalKey();
  final _rolesKey = GlobalKey();

  ActorModel get actor => widget.actor;

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  Future<void> _launchSms() async {
    // Fetch current user details
    final authState = ref.read(authControllerProvider);
    final uid = authState.uid;
    if (uid == null) {
      if (!mounted) return;
      showPremiumSnackbar(
        context,
        'You must be logged in to send SMS.',
        isError: true,
      );
      return;
    }

    String senderPhone = authState.phoneNumber ?? '';
    if (senderPhone.isEmpty) {
      if (!mounted) return;
      showPremiumSnackbar(
        context,
        'Your phone number is not available. Please re-login.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSendingSms = true;
    });

    String senderName = 'A user';
    String senderDesignation = kAattFullName;

    try {
      if (authState.status == AuthStatus.director) {
        final directorModel = await ref.read(
          getDirectorByUidProvider(uid).future,
        );
        if (directorModel != null) {
          senderName = directorModel.fullName;
          senderDesignation = directorModel.role.isNotEmpty
              ? directorModel.role
              : 'Director/Producer';

          // Capitalize designation
          if (senderDesignation.isNotEmpty) {
            senderDesignation =
                senderDesignation[0].toUpperCase() +
                senderDesignation.substring(1);
          }
        }
      } else if (authState.status == AuthStatus.actor) {
        final actorModel = await ref.read(actorProfileProvider(uid).future);
        if (actorModel != null) {
          senderName = actorModel.name;
          senderDesignation = 'Actor';
        }
      }

      senderName = senderName.trim().isEmpty
          ? 'AATT member'
          : senderName.trim();
      senderDesignation = senderDesignation.trim().isEmpty
          ? kAattFullName
          : senderDesignation.trim();
      senderPhone = senderPhone.trim();

      if (senderPhone.isEmpty) {
        if (!mounted) return;
        showPremiumSnackbar(
          context,
          'Your phone number is not available. Please re-login.',
          isError: true,
        );
        return;
      }

      // Call Cloud Function
      final httpsCallable = FirebaseFunctions.instance.httpsCallable(
        'sendMaskedNotification',
      );

      if (!mounted) return;
      showPremiumSnackbar(context, 'Sending SMS in background...');

      await httpsCallable.call({
        'targetId': actor.id,
        'senderName': senderName,
        'senderDesignation': senderDesignation,
        'senderPhone': senderPhone,
      });

      if (!mounted) return;
      showPremiumSnackbar(context, 'SMS sent successfully!');
    } catch (e) {
      if (!mounted) return;
      String errorMsg = 'Failed to send SMS. Please try again.';
      if (e is FirebaseFunctionsException) {
        errorMsg = e.message ?? errorMsg;
      }
      showPremiumSnackbar(context, errorMsg, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSendingSms = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = actor.contactMasked
        ? 'Contact masked \u2022 tap Send SMS to connect'
        : (actor.phone ?? '');

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Profile image
                SizedBox(
                  height: 400,
                  width: double.infinity,
                  child: actor.avatar != null && actor.avatar!.isNotEmpty
                      ? Hero(
                          tag: 'actor_avatar_${actor.id}',
                          child: PremiumNetworkImage(
                            imageUrl: actor.avatar!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          color: _K.chip,
                          child: const Icon(
                            Icons.person,
                            size: 80,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                ),

                // Gradient overlay for readability
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 140,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ),

                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: _K.ink,
                      ),
                    ),
                  ),
                ),

                // Wishlist button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: WishlistHeartButton(actorId: actor.id, size: 22),
                  ),
                ),

                // Name + subtitle overlay
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actor.name,
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),

                // Stats row
                _StatsRow(
                  actor: actor,
                  onSerialsTap: () => _scrollToKey(_serialsKey),
                  onMoviesTap: () => _scrollToKey(_moviesKey),
                ),
                const SizedBox(height: 24),

                // Action buttons
                _buildActionRow(),
                if (actor.contactMasked) ...[
                  const SizedBox(height: 8),
                  Text(
                    '*Contact details are masked. Use Send SMS to reach actor.',
                    style: GoogleFonts.inter(fontSize: 11, color: _K.inkSoft),
                  ),
                ],
                const SizedBox(height: 24),

                // Detail sections
                _DetailSection(
                  key: _rolesKey,
                  title: 'Roles',
                  icon: Icons.theater_comedy_rounded,
                  items: actor.rolesActed,
                  emptyText: 'Actor',
                ),
                const SizedBox(height: 14),
                _DetailSection(
                  title: 'Skills',
                  icon: Icons.workspace_premium_rounded,
                  items: actor.skills,
                  emptyText: 'No skills added yet',
                ),
                const SizedBox(height: 14),
                _DetailSection(
                  key: _serialsKey,
                  title: 'Serials Acted In',
                  icon: Icons.live_tv_rounded,
                  items: actor.serialsActed,
                  emptyText: 'No serials listed yet',
                ),
                const SizedBox(height: 14),
                _MoviesSection(
                  key: _moviesKey,
                  movieNames: actor.moviesActed,
                  movies: actor.movies,
                ),
                const SizedBox(height: 24),

                // About
                _buildAbout(),
                const SizedBox(height: 24),

                // Media
                _buildMediaFilter(),
                const SizedBox(height: 16),
                _buildCarousel(),
                const SizedBox(height: 8),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, size: 14, color: _K.inkSoft),
                      const SizedBox(width: 4),
                      Text(
                        'swipe',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _K.inkSoft,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 14, color: _K.inkSoft),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSendingSms ? null : _launchSms,
              style: ElevatedButton.styleFrom(
                backgroundColor: _K.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                shadowColor: _K.blue.withValues(alpha: 0.3),
              ),
              child: _isSendingSms
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sms_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Send SMS',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: _K.border, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: WishlistHeartButton(actorId: actor.id),
        ),
      ],
    );
  }

  Widget _buildAbout() {
    final text = (actor.about ?? '').trim();
    final content = text.isEmpty ? 'No bio added yet.' : text;
    final canTrim = content.length > 120;
    final display = canTrim && !_aboutExpanded
        ? '${content.substring(0, 120)}...'
        : content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _K.bluePale,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: _K.blue,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'About',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _K.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: canTrim
                ? () => setState(() => _aboutExpanded = !_aboutExpanded)
                : null,
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.6,
                  color: _K.inkSoft,
                ),
                children: [
                  TextSpan(text: display),
                  if (canTrim && !_aboutExpanded)
                    TextSpan(
                      text: ' Read More',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _K.blue,
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

  Widget _buildMediaFilter() {
    const labels = ['All', 'Pics', 'Videos'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(labels.length, (index) {
        final selected = index == _selectedTab;
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
          child: GestureDetector(
            onTap: () => setState(() => _selectedTab = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? _K.ink : Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: selected ? _K.ink : _K.border,
                  width: 1.5,
                ),
              ),
              child: Text(
                labels[index],
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _K.ink,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  String? _extractYouTubeId(String url) {
    if (url.isEmpty) return null;
    try {
      final Uri uri = Uri.parse(url);
      if (uri.host.contains('youtube.com') ||
          uri.host.contains('youtube-nocookie.com') ||
          uri.host.contains('m.youtube.com')) {
        if (uri.pathSegments.contains('embed') &&
            uri.pathSegments.last != 'embed') {
          return uri.pathSegments.last;
        }
        if (uri.pathSegments.isNotEmpty &&
            (uri.pathSegments.first == 'shorts' ||
                uri.pathSegments.first == 'live') &&
            uri.pathSegments.length >= 2) {
          return uri.pathSegments[1];
        }
        if (uri.queryParameters.containsKey('v')) {
          return uri.queryParameters['v'];
        }
      } else if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
    } catch (_) {
      // Ignore parse errors
    }
    return null;
  }

  Uri? _normalizePlayableUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://$trimmed');
      if (uri == null) return null;
    }

    // Convert bare youtube shorts links into standard watch links when needed.
    final isYouTubeHost =
        uri.host.contains('youtube.com') ||
        uri.host.contains('youtu.be') ||
        uri.host.contains('youtube-nocookie.com') ||
        uri.host.contains('m.youtube.com');
    if (isYouTubeHost) {
      final videoId = _extractYouTubeId(uri.toString());
      if (videoId != null && videoId.isNotEmpty) {
        return Uri.parse('https://www.youtube.com/watch?v=$videoId');
      }
    }

    return uri;
  }

  Future<bool> _tryLaunchVideo(Uri uri) async {
    // Web works better with explicit new-tab launch.
    if (kIsWeb) {
      return launchUrl(uri, webOnlyWindowName: '_blank');
    }

    // On mobile/desktop, try multiple modes to maximize compatibility.
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return true;
    }
    if (await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      return true;
    }
    return launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }

  Widget _buildVideoThumbnail(String url) {
    final videoId = _extractYouTubeId(url);
    final thumbnailUrl = videoId != null
        ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
        : '';

    return GestureDetector(
      onTap: () async {
        final uri = _normalizePlayableUri(url);
        if (uri == null) {
          if (!mounted) return;
          showPremiumSnackbar(context, 'Invalid video URL.', isError: true);
          return;
        }

        final launched = await _tryLaunchVideo(uri);
        if (!launched) {
          if (!mounted) return;
          showPremiumSnackbar(
            context,
            'Could not launch video. Please check the link or try again.',
            isError: true,
          );
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl.isNotEmpty)
            PremiumNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              borderRadius: 20,
            )
          else
            Container(color: _K.chip),
          Container(
            color: Colors.black.withValues(alpha: 0.2),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    final List<_MediaItem> items = [];
    final photos = actor.photos ?? const <String>[];
    final videos = actor.videoUrls ?? const <String>[];

    if (_selectedTab == 0) {
      items.addAll(photos.map((p) => _MediaItem(url: p, isVideo: false)));
      items.addAll(videos.map((v) => _MediaItem(url: v, isVideo: true)));
    } else if (_selectedTab == 1) {
      items.addAll(photos.map((p) => _MediaItem(url: p, isVideo: false)));
    } else if (_selectedTab == 2) {
      items.addAll(videos.map((v) => _MediaItem(url: v, isVideo: true)));
    }

    if (items.isEmpty) {
      final isVideoTab = _selectedTab == 2;
      return Container(
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _K.chip,
          borderRadius: BorderRadius.circular(16),
        ),
        child: EmptyStateWidget(
          icon: isVideoTab
              ? Icons.videocam_off_outlined
              : Icons.photo_library_outlined,
          title: isVideoTab ? 'No Videos' : 'No Media',
          subtitle: isVideoTab
              ? 'This actor hasn\'t uploaded any videos yet.'
              : 'This actor hasn\'t uploaded any media yet.',
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: PageView.builder(
        controller: _pageController,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                final delta = (_pageController.page ?? 0) - index;
                value = (1 - (delta.abs() * 0.14)).clamp(0.82, 1.0);
              }
              return Center(
                child: SizedBox(
                  height: Curves.easeOut.transform(value) * 300,
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: item.isVideo
                  ? _buildVideoThumbnail(item.url)
                  : PremiumNetworkImage(
                      imageUrl: item.url,
                      fit: BoxFit.cover,
                      borderRadius: 20,
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.actor, this.onSerialsTap, this.onMoviesTap});
  final ActorModel actor;
  final VoidCallback? onSerialsTap;
  final VoidCallback? onMoviesTap;

  @override
  Widget build(BuildContext context) {
    final serials = actor.serialsActed?.length ?? 0;
    final movies = (actor.movies?.length ?? 0) > 0
        ? actor.movies!.length
        : (actor.moviesActed?.length ?? 0);

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onSerialsTap,
            child: _StatCard(
              icon: Icons.live_tv_outlined,
              value: serials == 0 ? 'Info Not Available' : '$serials',
              label: 'Serials',
              color: const Color(0xFF4C4DDC),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onMoviesTap,
            child: _StatCard(
              icon: Icons.movie_outlined,
              value: movies == 0 ? 'Info Not Available' : '$movies',
              label: 'Movies',
              color: const Color(0xFFE8A838),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _K.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: value == 'Info Not Available' ? 13 : 20,
              fontWeight: FontWeight.w800,
              color: _K.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _K.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final List<String>? items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final values = (items ?? const <String>[])
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _K.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: _K.bluePale,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: _K.blue),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _K.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (values.isEmpty)
            Text(
              emptyText,
              style: GoogleFonts.inter(fontSize: 13, color: _K.inkSoft),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _K.chip,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _K.chipText,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _MediaItem {
  final String url;
  final bool isVideo;

  const _MediaItem({required this.url, required this.isVideo});
}

// ─── Movies Section ─────────────────────────────────────────────────────────

class _MoviesSection extends StatelessWidget {
  const _MoviesSection({
    super.key,
    required this.movies,
    required this.movieNames,
  });
  final List<MovieCredit>? movies;
  final List<String>? movieNames;

  @override
  Widget build(BuildContext context) {
    final credits = (movies ?? const <MovieCredit>[])
        .where((m) => m.title.trim().isNotEmpty)
        .toList();
    final plainMovieNames = (movieNames ?? const <String>[])
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .where(
          (name) => !credits.any(
            (credit) => credit.title.trim().toLowerCase() == name.toLowerCase(),
          ),
        )
        .toList();
    final hasAnyMovieData = credits.isNotEmpty || plainMovieNames.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _K.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: _K.bluePale,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.movie_outlined,
                  size: 16,
                  color: _K.blue,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Movies',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _K.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasAnyMovieData)
            Text(
              'No movies listed yet',
              style: GoogleFonts.inter(fontSize: 13, color: _K.inkSoft),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  credits
                      .map(
                        (movie) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _K.chip,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                movie.title,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _K.chipText,
                                ),
                              ),
                              if (movie.role != null &&
                                  movie.role!.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    '·',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _K.inkSoft,
                                    ),
                                  ),
                                ),
                                Text(
                                  movie.role!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _K.inkSoft,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                      .toList()
                    ..addAll(
                      plainMovieNames.map(
                        (name) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _K.chip,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _K.chipText,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
