import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/auth/models/auth_state.dart';
import 'package:aatt/core/widgets/ui_helpers.dart';

class RegisterPhoneScreen extends ConsumerStatefulWidget {
  const RegisterPhoneScreen({super.key});

  @override
  ConsumerState<RegisterPhoneScreen> createState() =>
      _RegisterPhoneScreenState();
}

class _RegisterPhoneScreenState extends ConsumerState<RegisterPhoneScreen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onGetReady() async {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final phone = digits.startsWith('0') ? digits.substring(1) : digits;
    if (phone.isEmpty || phone.length < 10) {
      _showError('Please enter a valid 10-digit mobile number.');
      return;
    }

    final completePhoneNumber = '+91$phone';
    await ref
        .read(authControllerProvider.notifier)
        .startRegistration(completePhoneNumber);
  }

  void _showError(String msg) {
    showPremiumSnackbar(context, msg, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isSendingOtp = authState.status == AuthStatus.sendingOtp;

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
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top white section ──────────────────────────────────────
              Expanded(
                flex: 55,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: size.height * 0.02),
                      // Title
                      Text(
                        'Create Account',
                        style: GoogleFonts.roboto(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1D1C31),
                          letterSpacing: 0.1,
                        ),
                      ),
                      const Spacer(),
                      // Illustration
                      Center(
                        child: Image.asset(
                          'assets/images/CreateAccount_illustration.png',
                          height: size.height * 0.28,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              SizedBox(
                            height: size.height * 0.28,
                            child: const Center(
                              child: Icon(Icons.image_not_supported,
                                  size: 50, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Bottom blue section ────────────────────────────────────
              Expanded(
                flex: 45,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1652FE),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34.0),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          // Discover. Cast. Create.
                          Text(
                            'Discover. Cast. Create.',
                            style: GoogleFonts.roboto(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.1,
                              height: 45 / 32,
                            ),
                          ),
                          const SizedBox(height: 5),
                          // Subtitle
                          Text(
                            'Access thousands of pre-screened actor profiles, Reach the right actors instantly, Connect safely via the Association network',
                            style: GoogleFonts.roboto(
                              fontSize: 13,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                              letterSpacing: 0.1,
                              height: 25 / 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          // Phone Input
                          Container(
                            height: 53,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: const Color(0xFFDFDFDF),
                                width: 0.7,
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                Text(
                                  '+91 ',
                                  style: GoogleFonts.roboto(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    onChanged: (value) => setState(() {}),
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Get Ready Button
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed:
                                  (isPhoneComplete && !isSendingOtp)
                                      ? _onGetReady
                                      : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 0,
                              ),
                              child: isSendingOtp
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Color(0xFF1652FE),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Get Ready',
                                      style: GoogleFonts.roboto(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Actor registration notice
                          Text(
                            'Actor registration is managed by AATT.\nContact the office to register as an actor.',
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              fontWeight: FontWeight.normal,
                              color: Colors.white70,
                              letterSpacing: 0.1,
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
            ],
          ),
        ),
      ),
    );
  }
}
