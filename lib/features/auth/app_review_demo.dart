/// Visible App Review demo login. This number must also be added in
/// Firebase Console → Authentication → Sign-in method → Phone →
/// "Phone numbers for testing" so OTP 123456 works without SMS.
class AppReviewDemo {
  AppReviewDemo._();

  static const phoneE164 = '+919999999999';
  static const phoneLocal = '9999999999';
  static const otp = '123456';

  static bool isDemoPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final local = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    return local == phoneLocal;
  }

  static String? otpFor(String? phone) {
    return isDemoPhone(phone) ? otp : null;
  }
}
