import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aatt/core/router/app_router.dart';
import 'package:aatt/features/auth/controllers/auth_controller.dart';

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    
    // Ensure accurate matching for exact routes or deeper routes
    // For Director, home is directorHome
    if (location.startsWith(AppRoutes.wishlist)) {
      return 1;
    }
    if (location.startsWith(AppRoutes.actorAnnouncements) || 
        location.startsWith(AppRoutes.announcementDetail) ||
        location.startsWith(AppRoutes.directorAnnouncements) ||
        location.startsWith(AppRoutes.directorCreateAnnouncement) ||
        location.startsWith(AppRoutes.directorAnnouncementDetail) ||
        location.startsWith(AppRoutes.directorAnnouncementSuccess)) {
      return 2;
    }
    if (location.startsWith(AppRoutes.actorProfileSettings) ||
        location.startsWith(AppRoutes.directorProfileSettings) ||
        location.startsWith(AppRoutes.actorProfileUpdate)) {
      return 3;
    }
    // Default to Home (0) if none match, which includes actorHome and directorHome
    return 0;
  }

  void _onItemTapped(int index, BuildContext context, WidgetRef ref) {
    if (index == _calculateSelectedIndex(context)) return;
    
    final role = ref.read(authControllerProvider).role;
    
    switch (index) {
      case 0:
        // Check user role to navigate to correct home
        if (role == 'director' || role == 'producer') {
           context.go(AppRoutes.directorHome);
        } else {
           context.go(AppRoutes.actorHome);
        }
        break;
      case 1:
        context.go(AppRoutes.wishlist);
        break;
      case 2:
        if (role == 'director' || role == 'producer') {
          context.go(AppRoutes.directorAnnouncements);
        } else {
          context.go(AppRoutes.actorAnnouncements);
        }
        break;
      case 3:
        if (role == 'director' || role == 'producer') {
          context.go(AppRoutes.directorProfileSettings);
        } else {
          context.go(AppRoutes.actorProfileSettings);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: selectedIndex,
        onTap: (index) => _onItemTapped(index, context, ref),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM NAV BAR
// ═══════════════════════════════════════════════════════════════════════════════

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.selectedIndex, required this.onTap});
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 78 + bottomInset,
      padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            isSelected: selectedIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.favorite_outline_rounded,
            label: 'Wishlist',
            isSelected: selectedIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: Icons.campaign_outlined,
            label: 'Posts',
            isSelected: selectedIndex == 2,
            onTap: () => onTap(2),
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Settings',
            isSelected: selectedIndex == 3,
            onTap: () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isSelected ? 1.0 : 0.96,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF0657F9) : const Color(0xFF9CA3AF),
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0657F9) : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
