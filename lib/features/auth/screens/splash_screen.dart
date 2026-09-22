import 'package:flutter/material.dart';
import 'package:aatt/core/theme/app_theme.dart';
import 'package:aatt/core/widgets/aatt_logo.dart';

/// Simple splash shown while Firebase Auth state resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AattLogo(size: 90),
            SizedBox(height: 36),
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
