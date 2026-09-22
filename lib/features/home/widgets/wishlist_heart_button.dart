import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aatt/core/widgets/ui_helpers.dart';
import 'package:aatt/features/home/providers/wishlist_controller.dart';

class WishlistHeartButton extends ConsumerStatefulWidget {
  const WishlistHeartButton({
    super.key,
    required this.actorId,
    this.size = 22,
  });

  final String actorId;
  final double size;

  @override
  ConsumerState<WishlistHeartButton> createState() =>
      _WishlistHeartButtonState();
}

class _WishlistHeartButtonState extends ConsumerState<WishlistHeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    _controller
      ..stop()
      ..forward(from: 0);

    try {
      await ref
          .read(wishlistControllerProvider.notifier)
          .toggleWishlist(widget.actorId);
    } catch (_) {
      if (!mounted) return;
      showPremiumSnackbar(
        context,
        'Failed to update wishlist. Please try again.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = ref.watch(
      wishlistControllerProvider.select(
        (state) => state.valueOrNull?.contains(widget.actorId) ?? false,
      ),
    );

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : const Color(0xFF9CA3AF),
            size: widget.size,
          ),
        ),
      ),
    );
  }
}
