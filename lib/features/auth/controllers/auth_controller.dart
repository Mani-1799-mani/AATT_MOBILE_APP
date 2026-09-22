import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aatt/features/auth/data/user_repository.dart';
import 'package:aatt/features/auth/data/director_repository.dart';
import 'package:aatt/features/auth/services/director_service.dart';
import 'package:aatt/features/auth/models/auth_state.dart';
import 'package:aatt/features/auth/app_review_demo.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

/// Provides the [AuthController] as a [StateNotifier].
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    firebaseAuth: FirebaseAuth.instance,
    userRepository: UserRepository(),
    directorService: DirectorService(DirectorRepository()),
  );
});

// ─── Controller ──────────────────────────────────────────────────────────────

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required FirebaseAuth firebaseAuth,
    required UserRepository userRepository,
    required DirectorService directorService,
  })  : _auth = firebaseAuth,
        _userRepo = userRepository,
        _directorService = directorService,
        super(const AuthState(status: AuthStatus.unknown)) {
    // Listen for Firebase auth state changes to bootstrap session.
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final FirebaseAuth _auth;
  final UserRepository _userRepo;
  final DirectorService _directorService;
  late final StreamSubscription<User?> _authSub;

  // Keep track internally so we can auto-resolve SMS code on Android.
  int? _resendToken;
  ConfirmationResult? _webConfirmationResult;

  static const _functionsRegion = 'us-central1';

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _functionsRegion);
  static const _minOtpIntervalSeconds = 10;

  // Rate-limiting: track last OTP send time.
  DateTime? _lastOtpSentAt;

  // ── Bootstrap ────────────────────────────────────────────────────────────

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      // Don't override sendingOtp / otpSent / verifyingOtp / claimingProfile state
      // when Firebase emits null during the phone-auth flow (no user yet).
      if (state.status == AuthStatus.sendingOtp ||
          state.status == AuthStatus.otpSent ||
          state.status == AuthStatus.verifyingOtp ||
          state.status == AuthStatus.claimingProfile) {
        return;
      }
      state = const AuthState(status: AuthStatus.unauthenticated);
    } else {
      // User exists in Firebase Auth. Look up their Firestore profile.
      await _resolveUserRole(user);
    }
  }

  /// After OTP verification (or app reopen), determine where to send the user.
  /// Calls the linkPhoneToActor Cloud Function first, then falls back to director lookup.
  Future<void> _resolveUserRole(User user) async {
    try {
      state = AuthState(
        status: AuthStatus.claimingProfile,
        uid: user.uid,
        phoneNumber: user.phoneNumber,
      );

      // 1. Try to link/claim an actor profile via Cloud Function
      try {
        final callable = _functions.httpsCallable('linkPhoneToActor');
        final result = await callable.call<Map<String, dynamic>>({});
        final data = result.data;

        if (data['success'] == true && data['actorId'] != null) {
          state = AuthState(
            status: AuthStatus.actor,
            uid: user.uid,
            phoneNumber: user.phoneNumber,
            role: 'actor',
            actorDocId: data['actorId'] as String,
          );
          return;
        }
      } on FirebaseFunctionsException catch (e) {
        // "not-found" means no actor profile for this phone — fall through to director check.
        // Any other error is unexpected.
        if (e.code != 'not-found') {
          debugPrint('linkPhoneToActor error: ${e.code} - ${e.message}');
        }
      } catch (e) {
        debugPrint('linkPhoneToActor unexpected error: $e');
      }

      // 2. Fallback: check by UID in actors (for already-linked profiles on app reopen)
      final actorResult = await _userRepo.getUserByUid(user.uid);
      if (actorResult != null) {
        state = AuthState(
          status: AuthStatus.actor,
          uid: user.uid,
          phoneNumber: user.phoneNumber,
          role: 'actor',
          actorDocId: actorResult.docId,
        );
        return;
      }

      // 3. Check the directors collection
      final directorProfile =
          await _directorService.getDirectorProfile(user.uid);
      if (directorProfile != null) {
        final role = directorProfile.role.toLowerCase();
        state = AuthState(
          status: AuthStatus.director,
          uid: user.uid,
          phoneNumber: user.phoneNumber,
          role: (role == 'director' || role == 'producer') ? role : 'director',
        );
        return;
      }

      // 4. No profile found → needs registration
      state = AuthState(
        status: AuthStatus.needsRegistration,
        uid: user.uid,
        phoneNumber: user.phoneNumber,
      );
    } catch (e) {
      debugPrint('Error in _resolveUserRole: $e');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Failed to load profile. $e',
      );
    }
  }

  // ── Phone Authentication ─────────────────────────────────────────────────

  /// Sends OTP for a visible App Review demo account without the
  /// "number must already be registered" login pre-check.
  Future<void> startAppReviewDemo(String phoneNumber) async {
    _lastOtpSentAt = null;
    await sendOtp(phoneNumber);
  }

  /// Step 1: Send OTP to the given phone number.
  Future<void> sendOtp(String phoneNumber) async {
    // Rate-limit: prevent spamming OTP requests.
    if (!AppReviewDemo.isDemoPhone(phoneNumber) && _lastOtpSentAt != null) {
      final elapsed = DateTime.now().difference(_lastOtpSentAt!).inSeconds;
      if (elapsed < _minOtpIntervalSeconds) {
        state = state.copyWith(
          errorMessage:
              'Please wait ${_minOtpIntervalSeconds - elapsed} seconds before requesting a new code.',
        );
        return;
      }
    }

    // Clear any previous error before starting.
    state = AuthState(
      status: AuthStatus.sendingOtp,
      phoneNumber: phoneNumber,
    );

    try {
      if (kIsWeb) {
        final result = await _auth.signInWithPhoneNumber(phoneNumber);
        _webConfirmationResult = result;
        _lastOtpSentAt = DateTime.now();
        state = AuthState(
          status: AuthStatus.otpSent,
          phoneNumber: phoneNumber,
          verificationId: 'web-confirmation',
        );
        return;
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: _onVerificationCompleted,
        verificationFailed: _onVerificationFailed,
        codeSent: _onCodeSent,
        codeAutoRetrievalTimeout: _onAutoRetrievalTimeout,
      );
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        phoneNumber: phoneNumber,
        errorMessage: _mapFirebaseAuthError(e),
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        phoneNumber: phoneNumber,
        errorMessage: _mapErrorMessage(e),
      );
    }
  }

  void _onVerificationCompleted(PhoneAuthCredential credential) async {
    // Auto-resolved on Android — sign in immediately.
    state = state.copyWith(status: AuthStatus.verifyingOtp);
    await _signInWithCredential(credential);
  }

  void _onVerificationFailed(FirebaseAuthException e) {
    state = AuthState(
      status: AuthStatus.unauthenticated,
      phoneNumber: state.phoneNumber,
      errorMessage: _mapFirebaseAuthError(e),
    );
  }

  void _onCodeSent(String verificationId, int? resendToken) {
    _resendToken = resendToken;
    _lastOtpSentAt = DateTime.now();
    state = AuthState(
      status: AuthStatus.otpSent,
      phoneNumber: state.phoneNumber,
      verificationId: verificationId,
    );
  }

  void _onAutoRetrievalTimeout(String verificationId) {
    // Keep verificationId valid; user can still enter manually.
    if (state.status == AuthStatus.otpSent) {
      state = state.copyWith(verificationId: verificationId);
    }
  }

  /// Step 2: Verify the 6-digit OTP code.
  Future<void> verifyOtp(String smsCode) async {
    if (kIsWeb) {
      final confirmation = _webConfirmationResult;
      if (confirmation == null) {
        state = state.copyWith(
          status: AuthStatus.otpSent,
          errorMessage: 'Session expired. Please resend the code.',
        );
        return;
      }

      state = state.copyWith(
        status: AuthStatus.verifyingOtp,
        errorMessage: null,
      );

      try {
        final result = await confirmation.confirm(smsCode);
        final user = result.user;
        if (user != null) {
          await _resolveUserRole(user);
        } else {
          state = state.copyWith(
            status: AuthStatus.otpSent,
            errorMessage: 'Sign-in failed. Please try again.',
          );
        }
      } on FirebaseAuthException catch (e) {
        state = AuthState(
          status: AuthStatus.otpSent,
          phoneNumber: state.phoneNumber,
          verificationId: state.verificationId,
          errorMessage: _mapFirebaseAuthError(e),
        );
      } catch (e) {
        state = AuthState(
          status: AuthStatus.otpSent,
          phoneNumber: state.phoneNumber,
          verificationId: state.verificationId,
          errorMessage: _mapErrorMessage(e),
        );
      }
      return;
    }

    final verificationId = state.verificationId;
    if (verificationId == null) {
      state = state.copyWith(
        errorMessage: 'Session expired. Please resend the code.',
      );
      return;
    }

    // Clear any previous error and set verifying state.
    state = state.copyWith(
      status: AuthStatus.verifyingOtp,
      errorMessage: null,
    );

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _signInWithCredential(credential);
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user != null) {
        await _resolveUserRole(user);
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Sign-in failed. Please try again.',
        );
      }
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.otpSent,
        phoneNumber: state.phoneNumber,
        verificationId: state.verificationId,
        errorMessage: _mapFirebaseAuthError(e),
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.otpSent,
        phoneNumber: state.phoneNumber,
        verificationId: state.verificationId,
        errorMessage: _mapErrorMessage(e),
      );
    }
  }

  // ── Registration ─────────────────────────────────────────────────────────

  /// Step 3: Register this user as Director or Producer.
  Future<void> registerDirector({
    required String firstName,
    required String lastName,
    required String role,
    String? productionHouse,
  }) async {
    final uid = state.uid ?? _auth.currentUser?.uid;
    final phone = state.phoneNumber ?? _auth.currentUser?.phoneNumber ?? '';

    if (uid == null) {
      state = state.copyWith(
        errorMessage: 'Not authenticated. Please sign in again.',
      );
      return;
    }

    try {
      // Use the DirectorService to create directors/producers in the directors collection
      await _directorService.createDirector(
        uid: uid,
        phoneNumber: phone,
        firstName: firstName,
        lastName: lastName,
        role: role.toLowerCase(),
        productionHouse: productionHouse,
      );

      state = AuthState(
        status: AuthStatus.director,
        uid: uid,
        phoneNumber: phone,
        role: role.toLowerCase(),
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Registration failed. Please try again.',
      );
    }
  }

  // ── Resend OTP ───────────────────────────────────────────────────────────

  Future<void> resendOtp() async {
    final phone = state.phoneNumber;
    if (phone != null && phone.isNotEmpty) {
      await sendOtp(phone);
    }
  }

  // ── Registration Flow (phone check + OTP) ────────────────────────────────

  /// Start the registration flow: check if phone already exists, then send OTP.
  Future<void> startRegistration(String phoneNumber) async {
    state = state.copyWith(
      status: AuthStatus.sendingOtp,
      phoneNumber: phoneNumber,
      errorMessage: null,
    );

    try {
      // Use the Cloud Function to check both actors (via phone_index) and directors
      final isRegistered = await checkPhoneRegistration(phoneNumber);

      if (isRegistered) {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage:
              'This number is already registered. Please login instead.',
        );
        return;
      }
      await sendOtp(phoneNumber);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Failed to check registration. Please try again.',
      );
    }
  }

  // ── Pre-Check Phone Registration ─────────────────────────────────────────

  /// Calls the checkPhoneRegistered Cloud Function to verify if a phone
  /// is registered as an actor or director BEFORE sending OTP.
  /// Returns true if the phone is registered in either collection.
  Future<bool> checkPhoneRegistration(String phoneNumber) async {
    try {
      final callable = _functions.httpsCallable('checkPhoneRegistered');
      final result = await callable.call<Map<String, dynamic>>({
        'phone': phoneNumber,
      });
      return result.data['registered'] == true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('checkPhoneRegistered error: ${e.code} - ${e.message}');
      // On error, allow OTP to proceed (fail open for pre-check).
      return true;
    } catch (e) {
      debugPrint('checkPhoneRegistered unexpected error: $e');
      return true;
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── Error Mapping ────────────────────────────────────────────────────────

  /// Maps Firebase Auth error codes to user-friendly messages.
  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The phone number format is invalid. Please check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes before trying again.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please check the code and try again.';
      case 'session-expired':
        return 'The OTP has expired. Please request a new code.';
      case 'invalid-verification-id':
        return 'Session expired. Please request a new OTP.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'operation-not-allowed':
        return 'Phone sign-in is not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'app-not-authorized':
        return 'This app is not authorized for Firebase Authentication.';
      case 'invalid-app-credential':
        return 'Invalid app credential. Check Firebase phone auth and app verification setup.';
      case 'missing-client-identifier':
        return 'App verification failed. Rebuild the app after registering this device\'s SHA-1/SHA-256 in Firebase Console (Project settings → Your apps → Android).';
      case 'web-context-cancelled':
      case 'cancelled-popup-request':
        return 'Verification was cancelled. Please try again.';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed. Please try again.';
      case 'web-internal-error':
        return 'Web verification failed. Refresh the page and try again.';
      case 'missing-phone-number':
        return 'Please enter a phone number.';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      default:
        final msg = (e.message ?? '').toLowerCase();
        if (msg.contains('configuration_not_found')) {
          return 'Phone authentication is not configured for this project/web app. Enable Phone sign-in and add this web domain in Firebase Authentication settings.';
        }
        if (msg.contains('captcha')) {
          return 'reCAPTCHA setup failed. Check authorized domains and refresh the page.';
        }
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  /// Maps generic errors to user-friendly messages.
  String _mapErrorMessage(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (msg.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
