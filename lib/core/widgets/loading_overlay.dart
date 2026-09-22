import 'package:flutter/material.dart';
import 'package:aatt/core/theme/app_theme.dart';

/// Full-screen translucent loading overlay.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, this.message = 'Please wait…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(message, style: AppTextStyles.body),
            ],
          ),
        ),
      ),
    );
  }
}
