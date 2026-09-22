import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aatt/features/home/models/advertisement_model.dart';
import 'package:aatt/features/home/providers/advertisement_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ADVERTISEMENT BANNER — single ad or auto-scrolling carousel (equal slide size)
// ═══════════════════════════════════════════════════════════════════════════════

const _defaultBannerAspectRatio = 16 / 9;

class AdvertisementBanner extends ConsumerWidget {
  const AdvertisementBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsAsync = ref.watch(homeAdvertisementsProvider);

    return adsAsync.when(
      data: (ads) {
        if (ads.isEmpty) return const SizedBox.shrink();
        if (ads.length == 1) return _SingleBanner(ad: ads.first);
        return _CarouselBanner(ads: ads);
      },
      loading: () => const _BannerShimmer(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// ─── Single Banner ───────────────────────────────────────────────────────────

class _SingleBanner extends StatelessWidget {
  const _SingleBanner({required this.ad});
  final AdvertisementModel ad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: _AdCard(ad: ad),
    );
  }
}

// ─── Carousel Banner ─────────────────────────────────────────────────────────

class _CarouselBanner extends StatefulWidget {
  const _CarouselBanner({required this.ads});
  final List<AdvertisementModel> ads;

  @override
  State<_CarouselBanner> createState() => _CarouselBannerState();
}

class _CarouselBannerState extends State<_CarouselBanner> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  double _slideAspectRatio = _defaultBannerAspectRatio;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startAutoScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resolveSlideAspectRatio();
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Use the second banner's proportions as the uniform size for every slide.
  void _resolveSlideAspectRatio() {
    final referenceAd =
        widget.ads.length >= 2 ? widget.ads[1] : widget.ads.first;
    final url = referenceAd.bannerUrl;
    if (url.isEmpty) return;

    final provider = CachedNetworkImageProvider(url);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (width > 0 && height > 0 && mounted) {
          setState(() => _slideAspectRatio = width / height);
        }
        stream.removeListener(listener);
      },
      onError: (_, __) => stream.removeListener(listener),
    );
    stream.addListener(listener);
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % widget.ads.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth * 0.92;
        final carouselHeight = pageWidth / _slideAspectRatio;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: carouselHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.ads.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _AdCard(
                      ad: widget.ads[index],
                      aspectRatio: _slideAspectRatio,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.ads.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF1652F0)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

// ─── Shared Ad Card ──────────────────────────────────────────────────────────

class _AdCard extends StatelessWidget {
  const _AdCard({
    required this.ad,
    this.aspectRatio,
    this.fit = BoxFit.contain,
  });

  final AdvertisementModel ad;
  final double? aspectRatio;
  final BoxFit fit;

  Future<void> _handleTap() async {
    recordAdClick(ad.id);
    final url = ad.targetUrl;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _AdaptiveBannerImage(
          imageUrl: ad.bannerUrl,
          aspectRatio: aspectRatio,
          fit: fit,
        ),
      ),
    );
  }
}

// ─── Adaptive banner (full image, no crop) ───────────────────────────────────

class _AdaptiveBannerImage extends StatefulWidget {
  const _AdaptiveBannerImage({
    required this.imageUrl,
    this.aspectRatio,
    this.fit = BoxFit.contain,
  });

  final String imageUrl;
  final double? aspectRatio;
  final BoxFit fit;

  @override
  State<_AdaptiveBannerImage> createState() => _AdaptiveBannerImageState();
}

class _AdaptiveBannerImageState extends State<_AdaptiveBannerImage> {
  double? _aspectRatio;
  ImageStream? _imageStream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _aspectRatio = widget.aspectRatio;
    if (_aspectRatio == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _aspectRatio != null) return;
        _resolveAspectRatio();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _AdaptiveBannerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.aspectRatio != null && widget.aspectRatio != _aspectRatio) {
      _aspectRatio = widget.aspectRatio;
      return;
    }
    if (oldWidget.imageUrl != widget.imageUrl && widget.aspectRatio == null) {
      _removeListener();
      _aspectRatio = null;
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
    _imageStream = null;
    _listener = null;
  }

  void _resolveAspectRatio() {
    if (widget.imageUrl.isEmpty || widget.aspectRatio != null) return;

    final provider = CachedNetworkImageProvider(widget.imageUrl);
    final stream = provider.resolve(const ImageConfiguration());
    _imageStream = stream;
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (mounted && width > 0 && height > 0) {
          setState(() => _aspectRatio = width / height);
        }
        _removeListener();
      },
      onError: (_, __) {
        if (mounted) {
          setState(() => _aspectRatio = _defaultBannerAspectRatio);
        }
        _removeListener();
      },
    );
    stream.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final ratio = _aspectRatio ?? _defaultBannerAspectRatio;
        final height = width / ratio;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: width,
            height: height,
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              width: width,
              height: height,
              fit: widget.fit,
              memCacheWidth: 1200,
              maxWidthDiskCache: 1600,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (context, url) => Container(
                color: const Color(0xFFE5E7EB),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: const Color(0xFFE5E7EB),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, color: Color(0xFF9CA3AF)),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Shimmer Placeholder ─────────────────────────────────────────────────────

class _BannerShimmer extends StatelessWidget {
  const _BannerShimmer();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 32;
    final height = width / _defaultBannerAspectRatio;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
