import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aatt/core/router/app_router.dart';
import 'package:aatt/core/services/storage_service.dart';
import 'package:aatt/core/widgets/ui_helpers.dart';
import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/auth/models/director_model.dart';
import 'package:aatt/features/auth/providers/director_providers.dart';

class _Tok {
  _Tok._();

  static const white = Colors.white;
  static const ink = Color(0xFF111827);
  static const sub = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const blue = Color(0xFF0657F9);
  static const bluePale = Color(0xFFEFF6FF);
  static const danger = Color(0xFFEF4444);
}

class DirectorProfileSettingsScreen extends ConsumerStatefulWidget {
  const DirectorProfileSettingsScreen({super.key});

  @override
  ConsumerState<DirectorProfileSettingsScreen> createState() =>
      _DirectorProfileSettingsScreenState();
}

class _DirectorProfileSettingsScreenState
    extends ConsumerState<DirectorProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _productionHouseController = TextEditingController();
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();

  bool _isSaving = false;
  bool _didPrefill = false;
  XFile? _pickedProfileImage;
  Uint8List? _pickedProfileImageBytes;
  String? _currentProfileImageUrl;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _productionHouseController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  void _prefillIfNeeded(DirectorModel director) {
    if (_didPrefill) return;
    _didPrefill = true;

    _firstNameController.text = director.firstName;
    _lastNameController.text = director.lastName;
    _emailController.text = director.email ?? '';
    _productionHouseController.text = director.productionHouse ?? '';
    _bioController.text = director.bio ?? '';
    _experienceController.text = director.experience?.toString() ?? '';
    _currentProfileImageUrl = director.profileImageUrl;
  }

  Future<void> _pickProfileImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedProfileImage = picked;
      _pickedProfileImageBytes = bytes;
    });
  }

  Future<void> _showAvatarActions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final canRemove =
            _pickedProfileImage != null || (_currentProfileImageUrl?.isNotEmpty ?? false);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(
                  'Choose Photo',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickProfileImage();
                },
              ),
              if (canRemove)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: _Tok.danger),
                  title: Text(
                    'Remove Photo',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: _Tok.danger,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _pickedProfileImage = null;
                      _pickedProfileImageBytes = null;
                      _currentProfileImageUrl = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save(DirectorModel current) async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final full = '$first $last'.trim();

    String? profileImageUrl = _currentProfileImageUrl;
    if (_pickedProfileImage != null) {
      try {
        profileImageUrl =
            await uploadDirectorProfileImage(_pickedProfileImage!, current.uid);
      } catch (e) {
        if (mounted) {
          showPremiumSnackbar(
            context,
            'Failed to upload profile image: $e',
            isError: true,
          );
        }
        if (mounted) setState(() => _isSaving = false);
        return;
      }
    }

    final updates = <String, dynamic>{
      'firstName': first,
      'lastName': last,
      'fullName': full,
      'email': _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      'productionHouse': _productionHouseController.text.trim().isEmpty
          ? null
          : _productionHouseController.text.trim(),
      'bio': _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
      'experience': _experienceController.text.trim().isEmpty
          ? null
          : int.parse(_experienceController.text.trim()),
        'profileImageUrl': profileImageUrl,
    };

    setState(() => _isSaving = true);
    try {
      await ref.read(directorRepositoryProvider).updateDirector(current.uid, updates);
      ref.invalidate(getDirectorByUidProvider(current.uid));
      if (mounted) {
        setState(() {
          _currentProfileImageUrl = profileImageUrl;
          _pickedProfileImage = null;
          _pickedProfileImageBytes = null;
        });
        showPremiumSnackbar(context, 'Profile updated successfully');
      }
    } catch (e) {
      if (mounted) {
        showPremiumSnackbar(context, 'Failed to update profile: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final uid = auth.uid ?? '';

    if (uid.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final directorAsync = ref.watch(getDirectorByUidProvider(uid));

    return Scaffold(
      backgroundColor: _Tok.white,
      appBar: AppBar(
        backgroundColor: _Tok.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _Tok.ink),
        ),
        title: Text(
          'Profile & Settings',
          style: GoogleFonts.inter(
            color: _Tok.ink,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: directorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load profile: $error',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _Tok.sub),
            ),
          ),
        ),
        data: (director) {
          if (director == null) {
            return Center(
              child: Text(
                'Director/Producer profile not found.',
                style: GoogleFonts.inter(color: _Tok.sub),
              ),
            );
          }

          _prefillIfNeeded(director);

          final roleLabel = director.role.toLowerCase() == 'producer'
              ? 'Producer'
              : 'Director';

          return SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _Tok.bluePale,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCFE0FF)),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _showAvatarActions,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(color: const Color(0xFFCFE0FF)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _pickedProfileImageBytes != null
                                    ? Image.memory(
                                        _pickedProfileImageBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : (_currentProfileImageUrl?.isNotEmpty ?? false)
                                        ? CachedNetworkImage(
                                            imageUrl: _currentProfileImageUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget: (context, url, error) => const Icon(
                                              Icons.person_outline_rounded,
                                              color: _Tok.blue,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person_outline_rounded,
                                            color: _Tok.blue,
                                          ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: _Tok.blue,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                director.fullName,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _Tok.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                roleLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _Tok.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _readonlyField('Phone Number', director.phoneNumber),
                  const SizedBox(height: 12),
                  _editableField(
                    controller: _firstNameController,
                    label: 'First Name',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _editableField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _editableField(
                    controller: _emailController,
                    label: 'Email',
                  ),
                  const SizedBox(height: 12),
                  _editableField(
                    controller: _productionHouseController,
                    label: 'Production House',
                  ),
                  const SizedBox(height: 12),
                  _editableField(
                    controller: _experienceController,
                    label: 'Experience (years)',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null || parsed < 0 || parsed > 99) {
                        return 'Enter a valid number (0-99)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _editableField(
                    controller: _bioController,
                    label: 'Bio',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () => _save(director),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Tok.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, color: _Tok.danger),
                      label: Text(
                        'Log Out',
                        style: GoogleFonts.inter(
                          color: _Tok.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: const Color(0xFFFEF2F2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _Tok.sub,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: _Tok.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: _Tok.ink,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _editableField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _Tok.sub,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          style: GoogleFonts.inter(
            color: _Tok.ink,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _Tok.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _Tok.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _Tok.blue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
