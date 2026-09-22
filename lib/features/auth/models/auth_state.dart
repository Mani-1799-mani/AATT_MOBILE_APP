/// Possible authentication states in the app.
enum AuthStatus {
  /// Initial unknown state - still determining auth.
  unknown,

  /// User is not authenticated at all.
  unauthenticated,

  /// OTP is being sent (waiting for Firebase callback).
  sendingOtp,

  /// Firebase Auth completed, checking Firestore profile.
  authenticated,

  /// OTP has been sent; waiting for user to verify.
  otpSent,

  /// OTP is being verified against Firebase.
  verifyingOtp,

  /// OTP verified, now linking profile via Cloud Function.
  claimingProfile,

  /// Profile exists with role 'actor' → route to actor home.
  actor,

  /// Profile exists with role 'director' or 'producer' → route to director home.
  director,

  /// No profile found → route to registration.
  needsRegistration,
}

/// Immutable auth state model.
class AuthState {
  const AuthState({
    required this.status,
    this.uid,
    this.phoneNumber,
    this.verificationId,
    this.role,
    this.actorDocId,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? uid;
  final String? phoneNumber;
  final String? verificationId;
  final String? role;
  /// Firestore document ID for the actor profile.
  /// May differ from [uid] for admin-created actors.
  final String? actorDocId;
  final String? errorMessage;

  /// Whether the auth flow is currently processing (sending or verifying OTP).
  bool get isLoading =>
      status == AuthStatus.sendingOtp ||
      status == AuthStatus.verifyingOtp ||
      status == AuthStatus.claimingProfile;

  /// Whether the user is fully authenticated with a resolved role.
  bool get isAuthenticated =>
      status == AuthStatus.actor || status == AuthStatus.director;

  AuthState copyWith({
    AuthStatus? status,
    String? uid,
    String? phoneNumber,
    String? verificationId,
    String? role,
    String? actorDocId,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      verificationId: verificationId ?? this.verificationId,
      role: role ?? this.role,
      actorDocId: actorDocId ?? this.actorDocId,
      errorMessage: errorMessage,
    );
  }

  /// Returns a copy with the error message explicitly cleared.
  AuthState clearError() {
    return AuthState(
      status: status,
      uid: uid,
      phoneNumber: phoneNumber,
      verificationId: verificationId,
      role: role,
      actorDocId: actorDocId,
      errorMessage: null,
    );
  }

  @override
  String toString() =>
      'AuthState(status: $status, uid: $uid, phone: $phoneNumber, role: $role, actorDocId: $actorDocId)';
}
