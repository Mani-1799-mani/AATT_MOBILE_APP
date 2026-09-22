import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/auth/models/auth_state.dart';
import 'package:aatt/core/widgets/ui_helpers.dart';

class DirectorRegistrationScreen extends ConsumerStatefulWidget {
  const DirectorRegistrationScreen({super.key});

  @override
  ConsumerState<DirectorRegistrationScreen> createState() =>
      _DirectorRegistrationScreenState();
}

class _DirectorRegistrationScreenState
    extends ConsumerState<DirectorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _productionHouseController = TextEditingController();
  String? _selectedDesignation;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _productionHouseController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedDesignation == null) {
      _showError('Please select a designation.');
      return;
    }

    setState(() => _isLoading = true);

    await ref.read(authControllerProvider.notifier).registerDirector(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          role: _selectedDesignation!,
          productionHouse: _productionHouseController.text.trim(),
        );

    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    showPremiumSnackbar(context, msg, isError: true);
  }

  /// Builds a styled text field matching Figma input containers (170:598–618).
  Widget _buildCustomTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCFD3D4), width: 1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1D1C31),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              validator: validator,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: const Color(0xFFABAFB1),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a styled dropdown matching Figma input container (170:608–613).
  Widget _buildCustomDropdown({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCFD3D4), width: 1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1D1C31),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  hint,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: const Color(0xFFABAFB1),
                  ),
                ),
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        _showError(next.errorMessage!);
        if (mounted) setState(() => _isLoading = false);
      }
    });

    final size = MediaQuery.of(context).size;
    final isFormComplete = _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _selectedDesignation != null;

    return Scaffold(
      backgroundColor: const Color(0xFFD9E8F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.02),
                  // Illustration
                  Image.asset(
                    'assets/images/registration_illustration.png',
                    height: size.height * 0.25,
                    width: 231,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => SizedBox(
                      height: size.height * 0.25,
                      child: const Center(
                        child: Icon(Icons.image_not_supported,
                            size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),
                  // Registration Text
                  Text(
                    'Registration',
                    style: GoogleFonts.roboto(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1D1B20),
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // First Name
                  _buildCustomTextField(
                    label: 'First Name',
                    hint: 'Enter First Name',
                    controller: _firstNameController,
                    validator: (val) =>
                        (val == null || val.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  // Last Name
                  _buildCustomTextField(
                    label: 'Last Name',
                    hint: 'Enter Last Name',
                    controller: _lastNameController,
                    validator: (val) =>
                        (val == null || val.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  // Designation
                  _buildCustomDropdown(
                    label: 'Designation',
                    hint: 'Select Designation',
                    value: _selectedDesignation,
                    items: const ['Director', 'Producer'],
                    onChanged: (val) {
                      setState(() {
                        _selectedDesignation = val;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  // Production House
                  _buildCustomTextField(
                    label: 'Production House',
                    hint: 'Production House',
                    controller: _productionHouseController,
                  ),
                  const SizedBox(height: 32),
                  // Create Account Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (isFormComplete && !_isLoading) ? _onSubmit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFormComplete
                            ? const Color(0xFF1652FE)
                            : const Color(0xFFD9E8F7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Create Account',
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
