import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/auth/models/auth_state.dart';
import 'package:aatt/features/auth/app_review_demo.dart';
import 'package:aatt/core/router/app_router.dart';
import 'package:aatt/core/widgets/ui_helpers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isCheckingPhone = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onSendOtp() async {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final phone = digits.startsWith('0') ? digits.substring(1) : digits;
    if (phone.isEmpty || phone.length < 10) {
      _showError('Please enter a valid 10-digit mobile number.');
      return;
    }

    final completePhoneNumber = '+91$phone';

    if (AppReviewDemo.isDemoPhone(completePhoneNumber)) {
      await ref
          .read(authControllerProvider.notifier)
          .startAppReviewDemo(completePhoneNumber);
      return;
    }

    // Pre-check: verify the phone is registered before sending OTP
    setState(() => _isCheckingPhone = true);
    try {
      final isRegistered = await ref
          .read(authControllerProvider.notifier)
          .checkPhoneRegistration(completePhoneNumber);

      if (!mounted) return;

      if (!isRegistered) {
        setState(() => _isCheckingPhone = false);
        _showError(
          'This number is not registered. If you are a Director/Producer, tap Register below.',
        );
        return;
      }
    } finally {
      if (mounted) setState(() => _isCheckingPhone = false);
    }

    await ref.read(authControllerProvider.notifier).sendOtp(completePhoneNumber);
  }

  Future<void> _onAppReviewDemo() async {
    _phoneController.text = AppReviewDemo.phoneLocal;
    setState(() {});
    await ref
        .read(authControllerProvider.notifier)
        .startAppReviewDemo(AppReviewDemo.phoneE164);
  }

  Future<void> _openUrl(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      _showError('Unable to open link.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showPremiumSnackbar(context, msg, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isSendingOtp = authState.status == AuthStatus.sendingOtp;
    final isBusy = isSendingOtp || _isCheckingPhone;

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        _showError(next.errorMessage!);
      }
    });

    final size = MediaQuery.of(context).size;
    final isPhoneComplete = _phoneController.text.length == 10;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFEF7),
              Color(0xFFFCFFE5),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.08),
                  // Logo
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    height: size.height * 0.25,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: size.height * 0.05),
                  // Title
                  Text(
                    'Artistes Association of Telugu Television',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1D1B20),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Subtitle
                  Text(
                    'Log In or Sign Up',
                    style: GoogleFonts.roboto(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF435974),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Phone Input
                  Container(
                    height: 53,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFFDFDFDF), width: 0.7),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Text(
                          '+91 ',
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            onChanged: (value) => setState(() {}),
                            onSubmitted: (_) {
                              if (isPhoneComplete && !isBusy) _onSendOtp();
                            },
                            textInputAction: TextInputAction.done,
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter mobile number',
                              hintStyle: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                                color: const Color(0xFF596674),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 51,
                    child: ElevatedButton(
                      onPressed: (isPhoneComplete && !isBusy) ? _onSendOtp : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPhoneComplete ? const Color(0xFF1652FE) : const Color(0xFFD9E8F7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: isBusy
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Continue',
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // OR Divider
                  Text(
                    'OR',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: const Color(0xFF666666),
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 51,
                    child: ElevatedButton(
                      onPressed: () {
                        context.push(AppRoutes.registerPhone);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A62D0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Register',
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Register Subtitle
                  Text(
                    'Register as Director or Producer',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: const Color(0xFF666666),
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'App Review demo login',
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1D1B20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No SMS required. Phone 9999999999 · OTP 123456',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      color: const Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: isBusy ? null : _onAppReviewDemo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1652FE),
                        side: const BorderSide(color: Color(0xFF1652FE)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        'App Review demo login',
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.06),
                  // Terms and Privacy
                  Text.rich(
                    TextSpan(
                      style: GoogleFonts.roboto(
                        fontSize: 10,
                        fontWeight: FontWeight.normal,
                        color: const Color(0xFF9097A9),
                        letterSpacing: 0.1,
                      ),
                      children: [
                        const TextSpan(text: 'By continuing you agree to our '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => _openUrl(
                              Uri.parse('https://aatt.app/privacy-policy'),
                            ),
                            child: Text(
                              'Terms of service',
                              style: GoogleFonts.roboto(
                                fontSize: 10,
                                color: const Color(0xFF9097A9),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' & '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => _openUrl(
                              Uri.parse('https://aatt.app/privacy-policy'),
                            ),
                            child: Text(
                              'Privacy policy',
                              style: GoogleFonts.roboto(
                                fontSize: 10,
                                color: const Color(0xFF9097A9),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
