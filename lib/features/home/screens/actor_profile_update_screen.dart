import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/core/services/storage_service.dart';
import 'package:aatt/features/home/models/actor_model.dart';
import 'package:aatt/features/home/providers/actor_profile_provider.dart';
import 'package:aatt/core/widgets/ui_helpers.dart';

// ─── Design Tokens (from Figma node 187:3061) ──────────────────────────────
class _Tok {
  _Tok._();
  static const blueRibbon = Color(0xFF0657F9);
  static const persianBlue = Color(0xFF1D4ED8);
  static const vulcan = Color(0xFF0D121C);
  static const paleSky = Color(0xFF6B7280);
  static const slateGray = Color(0xFF64748B);
  static const athensGray = Color(0xFFE5E7EB);
  static const zumthor = Color(0xFFF5F6F8);
  static const pattensBlue = Color(0xFFDBEAFE);
  static const geyser = Color(0xFFD1D5DB);
  static const black1 = Color(0xFFCFD3D4);
  static const black2 = Color(0xFFABAFB1);
  static const warningRed = Color(0xFFDE0000);
  static const white = Colors.white;
  static const inputLabel = Color(0xFF1D1C31);
  static const aboutText = Color(0xFF353535);
}

/// Actor Profile Update screen.
/// Matches Figma design at node 187:3061.
class ActorProfileUpdateScreen extends ConsumerStatefulWidget {
  const ActorProfileUpdateScreen({super.key});

  @override
  ConsumerState<ActorProfileUpdateScreen> createState() =>
      _ActorProfileUpdateScreenState();
}

class _ActorProfileUpdateScreenState
    extends ConsumerState<ActorProfileUpdateScreen> {
  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();

  bool _isMasked = true;
  List<String> _roles = [];
  List<String> _serials = [];
  List<String> _movies = [];
  List<String> _photos = [];
  String? _avatarUrl;
  Uint8List? _avatarLocalBytes;
  bool _isSubmitting = false;
  bool _isUploadingMedia = false;

  // Original values for diff comparison
  ActorModel? _original;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _phoneCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  void _populateFromActor(ActorModel actor) {
    if (_original != null) return; // already populated
    _original = actor;
    _nameCtrl.text = actor.name;
    _heightCtrl.text = actor.height ?? '';
    _phoneCtrl.text = actor.phone ?? '';
    _aboutCtrl.text = actor.about ?? '';
    _isMasked = actor.contactMasked;
    _roles = List<String>.from(actor.rolesActed ?? []);
    _serials = List<String>.from(actor.serialsActed ?? []);
    _movies = List<String>.from(actor.moviesActed ?? []);
    _photos = List<String>.from(actor.photos ?? []);
    _avatarUrl = actor.avatar;
  }

  Future<void> _pickAndUploadAvatar() async {
    final orig = _original;
    if (orig == null) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _isUploadingMedia = true;
      _avatarLocalBytes = bytes;
    });

    try {
      final auth = ref.read(authControllerProvider);
      final uid = auth.uid ?? orig.id;
      final uploadedUrl = await uploadActorProfileImage(picked, uid);
      if (!mounted) return;
      setState(() {
        _avatarUrl = uploadedUrl;
      });
      showPremiumSnackbar(context, 'Profile photo updated in draft changes.');
    } catch (e) {
      if (!mounted) return;
      showPremiumSnackbar(context, 'Failed to upload profile photo: $e', isError: true);
      setState(() {
        _avatarLocalBytes = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
        });
      }
    }
  }

  // ── Roles Management ────────────────────────────────────────────────────

  void _removeRole(int index) {
    setState(() => _roles.removeAt(index));
  }

  void _addRole() {
    _addChipItem(
      title: 'Add Role',
      hint: 'e.g. Villain, Hero, Comedian',
      onAdd: (value) => setState(() => _roles.add(value)),
    );
  }

  void _removeSerial(int index) {
    setState(() => _serials.removeAt(index));
  }

  void _addSerial() {
    _addChipItem(
      title: 'Add Serial Name',
      hint: 'e.g. Kartheeka Deepam',
      onAdd: (value) => setState(() => _serials.add(value)),
    );
  }

  void _removeMovie(int index) {
    setState(() => _movies.removeAt(index));
  }

  void _addMovie() {
    _addChipItem(
      title: 'Add Movie Name',
      hint: 'e.g. Bahubali',
      onAdd: (value) => setState(() => _movies.add(value)),
    );
  }

  void _addChipItem({
    required String title,
    required String hint,
    required ValueChanged<String> onAdd,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: _Tok.black2, fontSize: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                onAdd(value);
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: _Tok.blueRibbon),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── Mask/Unmask Double Confirmation ────────────────────────────────────

  Future<void> _onMaskChanged(bool newValue) async {
    if (newValue == _isMasked) return;

    final action = newValue ? 'mask' : 'unmask';
    final actionTitle = newValue ? 'Mask Profile' : 'Unmask Profile';
    final description = newValue
        ? 'Your contact details will be hidden from directors. They will need to use Send SMS to reach you.'
        : 'Your contact details (phone number) will be visible to all directors browsing your profile.';

    // ── First confirmation ──
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          actionTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          description,
          style: GoogleFonts.inter(fontSize: 14, color: _Tok.paleSky, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: _Tok.paleSky)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _Tok.blueRibbon),
            child: Text('Continue',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // ── Second confirmation ──
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Are you sure?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Please confirm that you want to $action your profile. This change will require admin approval.',
          style: GoogleFonts.inter(fontSize: 14, color: _Tok.paleSky, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Go Back',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: _Tok.paleSky)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _Tok.blueRibbon),
            child: Text('Yes, $action',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (secondConfirm != true || !mounted) return;

    setState(() => _isMasked = newValue);
  }

  // ── Gallery Management ──────────────────────────────────────────────────

  Future<void> _pickAndUploadGallery({int? replaceIndex}) async {
    final orig = _original;
    if (orig == null) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;

    if (_photos.length >= 10 && replaceIndex == null) {
      showPremiumSnackbar(context, 'Maximum 10 gallery photos allowed.', isError: true);
      return;
    }

    setState(() => _isUploadingMedia = true);

    try {
      final auth = ref.read(authControllerProvider);
      final uid = auth.uid ?? orig.id;
      final uploadedUrl = await uploadActorGalleryImage(picked, uid);
      if (!mounted) return;

      setState(() {
        if (replaceIndex != null && replaceIndex >= 0 && replaceIndex < _photos.length) {
          _photos[replaceIndex] = uploadedUrl;
        } else {
          _photos = [..._photos, uploadedUrl];
        }
      });
      showPremiumSnackbar(context, 'Gallery image updated in draft changes.');
    } catch (e) {
      if (!mounted) return;
      showPremiumSnackbar(context, 'Failed to upload gallery image: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  void _onEditPhoto(int index) {
    _pickAndUploadGallery(replaceIndex: index);
  }

  void _onAddPhoto() {
    _pickAndUploadGallery();
  }

  void _onDeletePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  // ── Submit Approval Request ─────────────────────────────────────────────

  Future<void> _submitChanges() async {
    final orig = _original;
    if (orig == null) return;
    final auth = ref.read(authControllerProvider);

    final changes = <String, dynamic>{};

    if (_nameCtrl.text.trim() != orig.name) {
      changes['name'] = _nameCtrl.text.trim();
    }
    if ((_avatarUrl ?? '') != (orig.avatar ?? '')) {
      changes['avatar'] = _avatarUrl ?? '';
    }
    if (_phoneCtrl.text.trim() != (orig.phone ?? '')) {
      changes['phone'] = _phoneCtrl.text.trim();
    }
    if (_isMasked != orig.contactMasked) {
      changes['contactMasked'] = _isMasked;
    }
    if (_aboutCtrl.text.trim() != (orig.about ?? '')) {
      changes['about'] = _aboutCtrl.text.trim();
    }

    // Compare roles
    final origRoles = Set<String>.from(orig.rolesActed ?? []);
    final newRoles = Set<String>.from(_roles);
    if (!origRoles.containsAll(newRoles) ||
        !newRoles.containsAll(origRoles)) {
      changes['rolesActed'] = _roles;
    }

    // Compare serial names
    final origSerials = Set<String>.from(orig.serialsActed ?? []);
    final newSerials = Set<String>.from(_serials);
    if (!origSerials.containsAll(newSerials) ||
        !newSerials.containsAll(origSerials)) {
      changes['serialsActed'] = _serials;
    }

    // Compare movie names
    final origMovies = Set<String>.from(orig.moviesActed ?? []);
    final newMovies = Set<String>.from(_movies);
    if (!origMovies.containsAll(newMovies) ||
        !newMovies.containsAll(origMovies)) {
      changes['moviesActed'] = _movies;
    }

    // Compare photos
    final origPhotos = List<String>.from(orig.photos ?? []);
    if (_photos.length != origPhotos.length ||
        !_photos.asMap().entries.every((e) =>
            e.key < origPhotos.length &&
            origPhotos[e.key] == e.value)) {
      changes['photos'] = _photos;
    }

    // Height field (custom field, store if non-empty)
    if (_heightCtrl.text.trim() != (orig.height ?? '')) {
      changes['height'] = _heightCtrl.text.trim();
    }

    if (changes.isEmpty) {
      if (mounted) {
        showPremiumSnackbar(context, 'No changes detected.');
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await submitProfileApproval(
        requesterUid: auth.uid ?? orig.id,
        actorDocId: orig.id,
        actorName: orig.name,
        actorAvatar: orig.avatar,
        requestedChanges: changes,
      );
      ref.invalidate(actorProfileUpdateHistoryProvider);

      if (!mounted) return;
      showPremiumSnackbar(
          context, 'Change request submitted for admin approval!');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showPremiumSnackbar(
          context, 'Failed to submit request: $e',
          isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentActorProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: profileAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
                data: (actor) {
                  if (actor != null) _populateFromActor(actor);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // ── Warning Banner ──────────────────────────
                        _WarningBanner(),
                        const SizedBox(height: 20),

                        // ── Avatar ──────────────────────────────────
                        Center(
                          child: _AvatarWithBadge(
                            avatarUrl: _avatarUrl ?? actor?.avatar,
                            localBytes: _avatarLocalBytes,
                            onTap: _pickAndUploadAvatar,
                          ),
                        ),
                        if (_isUploadingMedia) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Uploading media...',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _Tok.paleSky,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),

                        // ── Personal Details Section ────────────────
                        Text(
                          'Personal Details',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _Tok.vulcan,
                            height: 24 / 16,
                          ),
                        ),
                        const SizedBox(height: 18),

                        _LabeledTextField(
                          label: 'Name',
                          hint: 'Enter Name',
                          controller: _nameCtrl,
                        ),
                        const SizedBox(height: 14),
                        _LabeledTextField(
                          label: 'Height',
                          hint: 'Enter Height',
                          controller: _heightCtrl,
                        ),
                        const SizedBox(height: 14),
                        _LabeledTextField(
                          label: 'Phone',
                          hint: 'Enter Phone',
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),

                        // ── Profile Masking (temporarily disabled) ────
                        _SectionLabel(label: 'PROFILE MASKING'),
                        const SizedBox(height: 14),
                        IgnorePointer(
                          child: Opacity(
                            opacity: 0.45,
                            child: _SegmentedControl(
                              isMasked: _isMasked,
                              onChanged: _onMaskChanged,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Profile masking is temporarily unavailable.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _Tok.paleSky,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Edit Roles ──────────────────────────────
                        _SectionLabel(label: 'EDIT ROLES'),
                        const SizedBox(height: 14),
                        _RolesWrap(
                          roles: _roles,
                          onRemove: _removeRole,
                          onAdd: _addRole,
                          addLabel: 'Add Role',
                        ),
                        const SizedBox(height: 20),

                        _SectionLabel(label: 'EDIT SERIALS'),
                        const SizedBox(height: 14),
                        _RolesWrap(
                          roles: _serials,
                          onRemove: _removeSerial,
                          onAdd: _addSerial,
                          addLabel: 'Add Serial',
                        ),
                        const SizedBox(height: 20),

                        _SectionLabel(label: 'EDIT MOVIES'),
                        const SizedBox(height: 14),
                        _RolesWrap(
                          roles: _movies,
                          onRemove: _removeMovie,
                          onAdd: _addMovie,
                          addLabel: 'Add Movie',
                        ),
                        const SizedBox(height: 20),

                        // ── Edit About ──────────────────────────────
                        _SectionLabel(label: 'EDIT ABOUT'),
                        const SizedBox(height: 14),
                        _AboutTextField(controller: _aboutCtrl),
                        const SizedBox(height: 20),

                        // ── Gallery ─────────────────────────────────
                        _SectionLabel(label: 'GALLERY'),
                        const SizedBox(height: 15),
                        _GalleryGrid(
                          photos: _photos,
                          onEdit: _onEditPhoto,
                          onDelete: _onDeletePhoto,
                          onAdd: _onAddPhoto,
                        ),
                        const SizedBox(height: 30),

                        // ── Submit Button ───────────────────────────
                        _SubmitButton(
                          isLoading: _isSubmitting || _isUploadingMedia,
                          onPressed: _submitChanges,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Tok.white.withValues(alpha: 0.8),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
        ),
      ),
      padding: const EdgeInsets.only(left: 8, top: 12, bottom: 13, right: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.chevron_left_rounded,
                  size: 28, color: _Tok.vulcan),
            ),
          ),
          const Spacer(),
          Text(
            'Update Profile',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _Tok.vulcan,
              letterSpacing: -0.4,
              height: 24 / 16,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ─── Warning Banner ──────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 29, color: _Tok.paleSky),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            'Changes require admin approval',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: _Tok.warningRed,
              height: 24.38 / 15,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Avatar with Edit Badge (reused pattern) ─────────────────────────────────

class _AvatarWithBadge extends StatelessWidget {
  const _AvatarWithBadge({
    this.avatarUrl,
    this.localBytes,
    required this.onTap,
  });

  final String? avatarUrl;
  final Uint8List? localBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF3F4F6),
                border: Border.all(color: _Tok.white, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
                child: localBytes != null
                  ? Image.memory(localBytes!, fit: BoxFit.cover)
                  : avatarUrl != null && avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Icon(Icons.person,
                        size: 48, color: Color(0xFF939393)),
                      errorWidget: (context, url, error) => const Icon(Icons.person,
                        size: 48, color: Color(0xFF939393)),
                    )
                    : const Icon(Icons.person,
                      size: 48, color: Color(0xFF939393)),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _Tok.blueRibbon,
                  shape: BoxShape.circle,
                  border: Border.all(color: _Tok.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.edit, size: 14, color: _Tok.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12.19,
        fontWeight: FontWeight.w600,
        color: _Tok.slateGray,
        letterSpacing: 0.61,
        height: 17.41 / 12.19,
      ),
    );
  }
}

// ─── Labeled Text Field ─────────────────────────────────────────────────────

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: _Tok.black1, width: 1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _Tok.inputLabel,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: _Tok.vulcan,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: _Tok.black2,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Segmented Control (Masked / Unmask) ────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.isMasked,
    required this.onChanged,
  });

  final bool isMasked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: _Tok.athensGray,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: 'Masked',
            isSelected: isMasked,
            onTap: () => onChanged(true),
          ),
          _SegmentButton(
            label: 'Unmask',
            isSelected: !isMasked,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? _Tok.blueRibbon : Colors.transparent,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 1.74,
                      offset: Offset(0, 0.87),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.19,
                fontWeight: FontWeight.w500,
                color: isSelected ? _Tok.white : _Tok.paleSky,
                height: 17.41 / 12.19,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Roles Wrap ──────────────────────────────────────────────────────────────

class _RolesWrap extends StatelessWidget {
  const _RolesWrap({
    required this.roles,
    required this.onRemove,
    required this.onAdd,
    required this.addLabel,
  });

  final List<String> roles;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 8,
      children: [
        ...roles.asMap().entries.map(
              (entry) => _RoleChip(
                label: entry.value,
                onRemove: () => onRemove(entry.key),
              ),
            ),
        _AddRoleButton(onTap: onAdd, label: addLabel),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.8, vertical: 7.84),
      decoration: BoxDecoration(
        color: _Tok.zumthor,
        border: Border.all(color: _Tok.pattensBlue, width: 0.87),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.19,
              fontWeight: FontWeight.w500,
              color: _Tok.persianBlue,
              height: 17.41 / 12.19,
            ),
          ),
          const SizedBox(width: 5.22),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 14, color: _Tok.persianBlue),
          ),
        ],
      ),
    );
  }
}

class _AddRoleButton extends StatelessWidget {
  const _AddRoleButton({required this.onTap, required this.label});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.8, vertical: 7.84),
        decoration: BoxDecoration(
          color: _Tok.white,
          border: Border.all(
            color: _Tok.geyser,
            width: 0.87,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14, color: _Tok.slateGray),
            const SizedBox(width: 5.22),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.19,
                fontWeight: FontWeight.w500,
                color: _Tok.slateGray,
                height: 17.41 / 12.19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── About Text Field ────────────────────────────────────────────────────────

class _AboutTextField extends StatelessWidget {
  const _AboutTextField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: _Tok.black1, width: 1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        minLines: 2,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _Tok.aboutText,
        ),
        decoration: InputDecoration(
          hintText: 'Write something about yourself…',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _Tok.black2,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }
}

// ─── Gallery Grid ────────────────────────────────────────────────────────────

class _GalleryGrid extends StatelessWidget {
  const _GalleryGrid({
    required this.photos,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final List<String> photos;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 155 / 181,
      ),
      itemCount: photos.length + 1,
      itemBuilder: (context, index) {
        if (index == photos.length) {
          return _GalleryAddItem(onTap: onAdd);
        }
        return _GalleryItem(
          imageUrl: photos[index],
          onEdit: () => onEdit(index),
          onDelete: () => onDelete(index),
        );
      },
    );
  }
}

class _GalleryItem extends StatelessWidget {
  const _GalleryItem({
    required this.imageUrl,
    required this.onEdit,
    required this.onDelete,
  });

  final String imageUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: const Color(0xFFF3F4F6),
              child: const Center(
                child: Icon(Icons.image, size: 32, color: Color(0xFF939393)),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: const Color(0xFFF3F4F6),
              child: const Center(
                child: Icon(Icons.broken_image,
                    size: 32, color: Color(0xFF939393)),
              ),
            ),
          ),
        ),

        // Blue edit badge (top-right)
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _Tok.blueRibbon,
                shape: BoxShape.circle,
                border: Border.all(color: _Tok.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.edit, size: 14, color: _Tok.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryAddItem extends StatelessWidget {
  const _GalleryAddItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _Tok.athensGray),
          color: _Tok.zumthor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_a_photo_outlined,
                  color: _Tok.slateGray, size: 24),
              const SizedBox(height: 8),
              Text(
                'Add Photo',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _Tok.slateGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Submit Button ──────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _Tok.persianBlue,
          foregroundColor: _Tok.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: const Color(0x4D3B82F6),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _Tok.white,
                ),
              )
            : Text(
                'Request Changes',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _Tok.white,
                  height: 24 / 16,
                ),
              ),
      ),
    );
  }
}
