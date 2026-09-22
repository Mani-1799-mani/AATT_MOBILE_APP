import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:go_router/go_router.dart';
import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/auth/models/auth_state.dart';
import 'package:aatt/features/auth/app_review_demo.dart';
import 'package:aatt/core/router/app_router.dart';
import 'package:aatt/core/widgets/ui_helpers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isVerifying = false;
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final phone = ref.read(authControllerProvider).phoneNumber;
      final demoOtp = AppReviewDemo.otpFor(phone);
      if (demoOtp != null && mounted && _otpController.text.isEmpty) {
        _otpController.text = demoOtp;
        setState(() {});
      }
    });
  }

  void _startCountdown() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Masks a phone number for display: +91 9876543210 → +91 ******3210
  String _maskPhone(String phone) {
    if (phone.length < 4) return phone;
    final visible = phone.substring(phone.length - 4);
    final masked = '*' * (phone.length - 4);
    // Insert space after country code if present
    if (phone.startsWith('+')) {
      final codeEnd = phone.indexOf(' ') > 0
          ? phone.indexOf(' ')
          : (phone.length > 3 ? 3 : phone.length);
      final code = phone.substring(0, codeEnd);
      final rest = phone.substring(codeEnd).replaceAll(' ', '');
      if (rest.length > 4) {
        return '$code ${'*' * (rest.length - 4)}$visible';
      }
      return '$code $visible';
    }
    return '$masked$visible';
  }

  Future<void> _onVerifyOtp(String code) async {
    if (code.length < 6 || _isVerifying) return;
    setState(() => _isVerifying = true);
    await ref.read(authControllerProvider.notifier).verifyOtp(code);
    if (mounted) setState(() => _isVerifying = false);
  }

  Future<void> _onResendOtp() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    await ref.read(authControllerProvider.notifier).resendOtp();
    if (mounted) {
      setState(() => _isResending = false);
      _startCountdown();
    }
  }

  void _onGoBack() {
    // Navigate back to login, resetting the auth state.
    ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go(AppRoutes.login);
  }

  void _showError(String msg) {
    if (!mounted) return;
    showPremiumSnackbar(context, msg, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final phone = authState.phoneNumber ?? '';
    final maskedPhone = _maskPhone(phone);
    final isOtpComplete = _otpController.text.length == 6;
    final isVerifyingState = authState.status == AuthStatus.verifyingOtp ||
        authState.status == AuthStatus.claimingProfile;

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        _showError(next.errorMessage!);
        // Clear the OTP field on error so user can re-enter
        _otpController.clear();
        if (mounted) setState(() => _isVerifying = false);
      }
    });

    // ── Pinput theme matching Figma (170:558) ─────────────────────────────
    final defaultPinTheme = PinTheme(
      width: 58,
      height: 53,
      textStyle: GoogleFonts.roboto(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF455BC6), width: 0.7),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF455BC6), width: 2),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.red.shade400, width: 1.5),
      ),
    );

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: size.height * 0.01),

                // ── Back Button Row ──────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _onGoBack,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF1D1B20),
                      size: 22,
                    ),
                    tooltip: 'Change phone number',
                  ),
                ),

                SizedBox(height: size.height * 0.01),

                // ── Illustration ──────────────────────────────────────
                Image.asset(
                  'assets/images/otp-image-illustrator.png',
                  height: size.height * 0.28,
                  width: 279,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => SizedBox(
                    height: size.height * 0.28,
                    child: const Center(
                      child: Icon(Icons.image_not_supported,
                          size: 50, color: Colors.grey),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ── Title ─────────────────────────────────────────────
                Text(
                  'Enter OTP',
                  style: GoogleFonts.roboto(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1D1B20),
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 18),

                // ── Subtitle ──────────────────────────────────────────
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                    children: [
                      const TextSpan(
                        text: "We've sent an OTP code to your mobile no\n",
                      ),
                      TextSpan(
                        text: maskedPhone,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4A62D0),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),
                if (AppReviewDemo.isDemoPhone(phone))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'App Review demo OTP: ${AppReviewDemo.otpFor(phone)}',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1652FE),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // ── OTP Input (6 boxes) ─────────────────────
                Pinput(
                  controller: _otpController,
                  focusNode: _focusNode,
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  errorPinTheme: errorPinTheme,
                  hapticFeedbackType: HapticFeedbackType.lightImpact,
                  closeKeyboardWhenCompleted: false,
                  onCompleted: _onVerifyOtp,
                  onChanged: (_) => setState(() {}),
                  separatorBuilder: (_) => const SizedBox(width: 12),
                  cursor: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        width: 22,
                        height: 2,
                        decoration: BoxDecoration(
                          color: const Color(0xFF455BC6),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ── Resend timer ──────────────────────────────────────
                if (_secondsRemaining > 0)
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                      children: [
                        const TextSpan(text: 'We will resend the code in '),
                        TextSpan(
                          text: '${_secondsRemaining}s',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _isResending ? null : _onResendOtp,
                    child: Text(
                      _isResending ? 'Sending...' : 'Resend OTP',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isResending
                            ? Colors.grey
                            : const Color(0xFF4A62D0),
                      ),
                    ),
                  ),

                const SizedBox(height: 22),

                // ── Continue Button ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (isOtpComplete && !_isVerifying && !isVerifyingState)
                        ? () => _onVerifyOtp(_otpController.text)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOtpComplete
                          ? const Color(0xFF1652FE)
                          : const Color(0xFFE5E7EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: (_isVerifying || isVerifyingState)
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Continue',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Change Number hint ────────────────────────────────
                GestureDetector(
                  onTap: _onGoBack,
                  child: Text(
                    'Change phone number',
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4A62D0),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
