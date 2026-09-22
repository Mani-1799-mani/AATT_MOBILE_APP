import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/auth/models/auth_state.dart';
import 'package:aatt/features/auth/screens/login_screen.dart';
import 'package:aatt/features/auth/screens/otp_screen.dart';
import 'package:aatt/features/auth/screens/director_registration_screen.dart';
import 'package:aatt/features/auth/screens/register_phone_screen.dart';
import 'package:aatt/features/home/screens/actor_home_screen.dart';
import 'package:aatt/features/home/screens/actor_profile_screen.dart';
import 'package:aatt/features/home/screens/actor_profile_settings_screen.dart';
import 'package:aatt/features/home/screens/director_profile_settings_screen.dart';
import 'package:aatt/features/home/screens/actor_profile_update_screen.dart';
import 'package:aatt/features/home/screens/actor_announcements_screen.dart';
import 'package:aatt/features/home/screens/announcement_detail_screen.dart';
import 'package:aatt/features/home/screens/director_home_screen.dart';
import 'package:aatt/features/home/screens/director_announcements_screen.dart';
import 'package:aatt/features/home/screens/create_announcement_screen.dart';
import 'package:aatt/features/home/screens/director_announcement_detail_screen.dart';
import 'package:aatt/features/home/screens/wishlist_screen.dart';
import 'package:aatt/features/home/models/actor_model.dart';
import 'package:aatt/features/home/models/announcement_model.dart';
import 'package:aatt/features/auth/screens/splash_screen.dart';
import 'package:aatt/core/widgets/main_scaffold.dart';

// ─── Route Paths ─────────────────────────────────────────────────────────────

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String registerPhone = '/register-phone';
  static const String registerDirector = '/register-director';
  static const String actorHome = '/actor-home';
  static const String directorHome = '/directory';
  static const String actorProfile = '/actor-profile';
  static const String actorProfileSettings = '/actor-profile-settings';
  static const String directorProfileSettings = '/director-profile-settings';
  static const String actorProfileUpdate = '/actor-profile-update';
  static const String actorAnnouncements = '/actor-announcements';
  static const String announcementDetail = '/announcement-detail';
  static const String wishlist = '/wishlist';

  // Director Announcements
  static const String directorAnnouncements = '/director-announcements';
  static const String directorCreateAnnouncement = '/director-create-announcement';
  static const String directorAnnouncementDetail = '/director-announcement-detail';
  static const String directorAnnouncementSuccess = '/director-announcement-success';
}


// ─── Router Provider ─────────────────────────────────────────────────────────

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: _AuthNotifier(ref),
    redirect: (context, routerState) {
      final status = authState.status;
      final currentPath = routerState.matchedLocation;

      // ── Splash: wait until auth resolves ───────────────────────────────
      if (status == AuthStatus.unknown) {
        return currentPath == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // ── Not authenticated → allow auth entry routes ───────────────────
      if (status == AuthStatus.unauthenticated) {
        if (currentPath == AppRoutes.login ||
            currentPath == AppRoutes.registerPhone ||
            currentPath == AppRoutes.registerDirector) {
          return null;
        }
        return AppRoutes.login;
      }

      // ── Sending OTP → stay on current screen (loading) ────────────────
      if (status == AuthStatus.sendingOtp) {
        // Allow staying on login, register-phone, or OTP while OTP is being sent
        if (currentPath == AppRoutes.login ||
            currentPath == AppRoutes.registerPhone ||
            currentPath == AppRoutes.otp) {
          return null;
        }
        return AppRoutes.login;
      }

      // ── OTP sent → must be on OTP screen ──────────────────────────────
      if (status == AuthStatus.otpSent) {
        return currentPath == AppRoutes.otp ? null : AppRoutes.otp;
      }

      // ── Verifying OTP → stay on OTP screen ────────────────────────────
      if (status == AuthStatus.verifyingOtp) {
        return currentPath == AppRoutes.otp ? null : AppRoutes.otp;
      }

      // ── Claiming profile → stay on OTP screen (shows "Linking profile…")
      if (status == AuthStatus.claimingProfile) {
        return currentPath == AppRoutes.otp ? null : AppRoutes.otp;
      }

      // ── Needs registration → send to registration ─────────────────────
      if (status == AuthStatus.needsRegistration) {
        return currentPath == AppRoutes.registerDirector
            ? null
            : AppRoutes.registerDirector;
      }

      // ── Actor role → actor home ───────────────────────────────────────
      if (status == AuthStatus.actor) {
        if (currentPath == AppRoutes.actorHome ||
            currentPath == AppRoutes.actorProfileSettings ||
            currentPath == AppRoutes.actorProfileUpdate ||
            currentPath.startsWith('${AppRoutes.actorProfile}/') ||
            currentPath == AppRoutes.actorAnnouncements ||
            currentPath == AppRoutes.announcementDetail ||
            currentPath == AppRoutes.wishlist) {
          return null;
        }
        return AppRoutes.actorHome;
      }

      // ── Director/Producer role → director home ────────────────────────
      if (status == AuthStatus.director) {
        if (currentPath == AppRoutes.directorHome ||
            currentPath == AppRoutes.directorProfileSettings ||
            currentPath.startsWith('${AppRoutes.actorProfile}/') ||
            currentPath == AppRoutes.actorAnnouncements ||
            currentPath == AppRoutes.announcementDetail ||
            currentPath == AppRoutes.directorAnnouncements ||
            currentPath == AppRoutes.directorCreateAnnouncement ||
            currentPath == AppRoutes.directorAnnouncementDetail ||
            currentPath == AppRoutes.directorAnnouncementSuccess ||
            currentPath == AppRoutes.wishlist) {
          return null;
        }
        return AppRoutes.directorHome;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.otp,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OtpScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.registerPhone,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterPhoneScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.registerDirector,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const DirectorRegistrationScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      // ─── Shell Route for authenticated pages ──────────────────────────────
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.actorHome,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ActorHomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: AppRoutes.directorHome,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const DirectorHomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '${AppRoutes.actorProfile}/:actorId',
            pageBuilder: (context, state) {
              final actor = state.extra is ActorModel
                  ? state.extra as ActorModel
                  : null;
              final actorId = state.pathParameters['actorId'] ?? '';
              return CustomTransitionPage(
                key: state.pageKey,
                child: ActorProfileRouteScreen(
                  actorId: actorId,
                  initialActor: actor,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.actorProfileSettings,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ActorProfileSettingsScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: AppRoutes.directorProfileSettings,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const DirectorProfileSettingsScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: AppRoutes.actorProfileUpdate,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ActorProfileUpdateScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: AppRoutes.actorAnnouncements,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ActorAnnouncementsScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: AppRoutes.announcementDetail,
            pageBuilder: (context, state) {
              final announcement = state.extra as AnnouncementDoc;
              return CustomTransitionPage(
                key: state.pageKey,
                child: AnnouncementDetailScreen(announcement: announcement),
                transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.wishlist,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const WishlistScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          // ─── Director Announcements ──────────────────────────────────────
          GoRoute(
            path: AppRoutes.directorAnnouncements,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const DirectorAnnouncementsScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: AppRoutes.directorCreateAnnouncement,
            pageBuilder: (context, state) {
              final existing = state.extra as AnnouncementDoc?;
              return CustomTransitionPage(
                key: state.pageKey,
                child: CreateAnnouncementScreen(existingAnnouncement: existing),
                transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.directorAnnouncementDetail,
            pageBuilder: (context, state) {
              final announcement = state.extra as AnnouncementDoc;
              return CustomTransitionPage(
                key: state.pageKey,
                child: DirectorAnnouncementDetailScreen(announcement: announcement),
                transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.directorAnnouncementSuccess,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const AnnouncementSuccessScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
        ],
      ),
    ],
  );
});

// ─── Listenable bridge for Riverpod → GoRouter refresh ───────────────────────

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
