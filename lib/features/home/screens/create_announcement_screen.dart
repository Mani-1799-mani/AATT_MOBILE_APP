import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:aatt/core/widgets/loading_overlay.dart';
import 'package:aatt/core/widgets/ui_helpers.dart';
import 'package:aatt/core/services/storage_service.dart';
import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/auth/providers/director_providers.dart';
import 'package:aatt/features/home/models/announcement_model.dart';
import 'package:aatt/features/home/providers/director_announcements_controller.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS — extracted from Figma node 223:16469
// ═══════════════════════════════════════════════════════════════════════════════

class _Tok {
  _Tok._();

  // Colours
  static const blueRibbon = Color(0xFF0657F9);
  static const ebony = Color(0xFF111827);
  static const oxfordBlue = Color(0xFF374151);
  static const riverBed = Color(0xFF4B5563);
  static const paleSky = Color(0xFF6B7280);
  static const grayChateau = Color(0xFF9CA3AF);
  static const athensGray = Color(0xFFF3F4F6);
  static const inputBg = Color(0xFFF9FAFB);
  static const inputBorder = Color(0xFFE5E7EB);
  static const segmentBg = Color(0xFFF5F6F8);

  // Typography (Be Vietnam Pro — mapped to Inter as Inter is used elsewhere)
  static final appBarTitle = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: ebony,
    letterSpacing: -0.45,
  );

  static final sectionHeading = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: ebony,
  );

  static final labelStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: oxfordBlue,
  );

  static final fieldLabelStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: riverBed,
  );

  static final inputTextStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: ebony,
  );

  static final hintStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: const Color(0xFFBFBFBF),
  );

  static final segmentActiveStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: blueRibbon,
  );

  static final segmentInactiveStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: paleSky,
  );

  static final uploadTitleStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: blueRibbon,
  );

  static final uploadSubStyle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: paleSky,
  );

  static final buttonStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static final errorStyle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: const Color(0xFFEF4444),
  );

  // Input decoration
  static InputDecoration inputDecoration({
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle,
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: blueRibbon, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      errorStyle: errorStyle,
      suffixIcon: suffixIcon,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATE ANNOUNCEMENT SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class CreateAnnouncementScreen extends ConsumerStatefulWidget {
  const CreateAnnouncementScreen({super.key, this.existingAnnouncement});

  /// If non-null, the form is in "edit" mode.
  final AnnouncementDoc? existingAnnouncement;

  @override
  ConsumerState<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState
    extends ConsumerState<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _selectedTypeIndex = 0;
  static const _types = ['Casting', 'Update', 'News'];

  DateTime? _startsAt;
  DateTime? _expiresAt;

  List<XFile> _bannerFiles = const [];
  List<Uint8List> _bannerBytes = const [];
  List<String> _existingBannerUrls = const [];

  bool get _isEditing => widget.existingAnnouncement != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _prefillForm();
    }
  }

  void _prefillForm() {
    final a = widget.existingAnnouncement!;
    _titleController.text = a.title;
    _descriptionController.text = a.description;

    // Try to extract type from tags
    for (int i = 0; i < _types.length; i++) {
      if (a.tags.any((t) => t.label.toLowerCase() == _types[i].toLowerCase())) {
        _selectedTypeIndex = i;
        break;
      }
    }

    _startsAt = a.startsAt;
    _expiresAt = a.expiresAt;
    _existingBannerUrls = a.mediaUrls;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _Tok.blueRibbon,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startsAt = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _Tok.blueRibbon,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _pickBannerImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked.isNotEmpty) {
      final selected = picked.take(4).toList();
      final bytes = <Uint8List>[];
      for (final file in selected) {
        bytes.add(await file.readAsBytes());
      }
      setState(() {
        _bannerFiles = selected;
        _bannerBytes = bytes;
        _existingBannerUrls = const [];
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startsAt != null && _expiresAt != null && _expiresAt!.isBefore(_startsAt!)) {
      showPremiumSnackbar(
        context,
        'End date must be after the start date',
        isError: true,
      );
      return;
    }

    final authState = ref.read(authControllerProvider);
    final uid = authState.uid ?? '';

    if (uid.isEmpty) {
      showPremiumSnackbar(
        context,
        'Session expired. Please sign in again to upload media.',
        isError: true,
      );
      return;
    }

    // Upload banner images if new files are selected.
    List<String> bannerImageUrls = _existingBannerUrls;
    if (_bannerFiles.isNotEmpty) {
      try {
        bannerImageUrls = await uploadAnnouncementBannerImages(_bannerFiles);
      } catch (e) {
        if (mounted) {
          showPremiumSnackbar(context, 'Failed to upload announcement media: $e',
              isError: true);
        }
        return;
      }
    }

    final thumbnailUrl = bannerImageUrls.isNotEmpty ? bannerImageUrls.first : null;

    if (_isEditing) {
      // Edit mode
      final tags = <AnnouncementTag>[
        AnnouncementTag(label: _types[_selectedTypeIndex]),
      ];

      await updateAnnouncement(
        announcementId: widget.existingAnnouncement!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        tags: tags,
        thumbnailUrl: thumbnailUrl,
        bannerImageUrls: bannerImageUrls,
        startsAt: _startsAt,
        expiresAt: _expiresAt,
      );

      if (mounted) {
        showPremiumSnackbar(context, 'Announcement resubmitted for review');
        context.pushReplacement('/director-announcement-success');
      }
      return;
    }

    // Create mode
    // Fetch director profile for submitter info
    final directorAsync =
        await ref.read(getDirectorByUidProvider(uid).future);
    final submitterName = directorAsync?.fullName ?? 'Director';
    final submitterAvatar = directorAsync?.profileImageUrl ?? '';

    final controller = ref.read(createAnnouncementProvider.notifier);
    final success = await controller.submit(
      submitterUid: uid,
      submitterName: submitterName,
      submitterAvatar: submitterAvatar,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      tags: const [],
      type: _types[_selectedTypeIndex],
      thumbnailUrl: thumbnailUrl,
      bannerImageUrls: bannerImageUrls,
      startsAt: _startsAt,
      expiresAt: _expiresAt,
    );

    if (success && mounted) {
      context.pushReplacement('/director-announcement-success');
    } else if (mounted) {
      showPremiumSnackbar(context, 'Failed to post announcement', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createAnnouncementProvider);
    final isLoading = createState.isSubmitting;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: _Tok.ebony),
              onPressed: () => context.pop(),
            ),
            title: Text(
              _isEditing ? 'Edit Announcement' : 'New Announcement',
              style: _Tok.appBarTitle,
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Container(
                height: 0.5,
                color: const Color(0xFFDCDCDC),
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title ──
                        Text('Announcement Title', style: _Tok.labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          style: _Tok.inputTextStyle,
                          decoration: _Tok.inputDecoration(),
                          onChanged: (_) => setState(() {}),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                        ),

                        const SizedBox(height: 20),

                        // ── Type Selector ──
                        Text('Type', style: _Tok.labelStyle),
                        const SizedBox(height: 6),
                        _TypeSegment(
                          types: _types,
                          selectedIndex: _selectedTypeIndex,
                          onChanged: (i) =>
                              setState(() => _selectedTypeIndex = i),
                        ),

                        const SizedBox(height: 20),

                        // ── Separator ──
                        const Divider(color: _Tok.athensGray, thickness: 1),
                        const SizedBox(height: 20),

                        // ── Description ──
                        Text('Description & Details', style: _Tok.labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descriptionController,
                          style: _Tok.inputTextStyle,
                          maxLines: 6,
                          minLines: 5,
                          onChanged: (_) => setState(() {}),
                          decoration: _Tok.inputDecoration(
                            hintText:
                                'Enter detailed role description, scripts, or notes...',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Description is required'
                              : null,
                        ),

                        const SizedBox(height: 20),

                        // ── Separator ──
                        const Divider(color: _Tok.athensGray, thickness: 1),
                        const SizedBox(height: 20),

                        // ── Thumbnail Section ──
                        Text('Tweet Media (up to 4 images)', style: _Tok.sectionHeading),
                        const SizedBox(height: 12),
                        _BannerMediaPicker(
                          bannerFiles: _bannerFiles,
                          bannerBytes: _bannerBytes,
                          existingUrls: _existingBannerUrls,
                          onPick: _pickBannerImages,
                          onRemove: () => setState(() {
                            _bannerFiles = const [];
                            _bannerBytes = const [];
                            _existingBannerUrls = const [];
                          }),
                        ),

                        const SizedBox(height: 16),
                        Text('Tweet Preview', style: _Tok.sectionHeading),
                        const SizedBox(height: 8),
                        _TweetPreviewCard(
                          authorName: 'You',
                          title: _titleController.text.trim(),
                          description: _descriptionController.text.trim(),
                          type: _types[_selectedTypeIndex],
                          memoryImages: _bannerBytes,
                          networkImages: _existingBannerUrls,
                        ),

                        const SizedBox(height: 20),

                        // ── Separator ──
                        const Divider(color: _Tok.athensGray, thickness: 1),
                        const SizedBox(height: 20),

                        // ── Schedule Section ──
                        Text('Schedule', style: _Tok.sectionHeading),
                        const SizedBox(height: 20),

                        // ── Start Date ──
                        Text('Start Date', style: _Tok.fieldLabelStyle),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickStartDate,
                          child: AbsorbPointer(
                            child: TextFormField(
                              style: _Tok.inputTextStyle,
                              decoration: _Tok.inputDecoration(
                                hintText: _startsAt != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(_startsAt!)
                                    : 'Today (default)',
                                suffixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: _Tok.grayChateau,
                                ),
                              ),
                              controller: TextEditingController(
                                text: _startsAt != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(_startsAt!)
                                    : '',
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── End Date ──
                        Text('End Date', style: _Tok.fieldLabelStyle),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickEndDate,
                          child: AbsorbPointer(
                            child: TextFormField(
                              style: _Tok.inputTextStyle,
                              decoration: _Tok.inputDecoration(
                                hintText: _expiresAt != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(_expiresAt!)
                                    : 'Select end date',
                                suffixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: _Tok.grayChateau,
                                ),
                              ),
                              controller: TextEditingController(
                                text: _expiresAt != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(_expiresAt!)
                                    : '',
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Reference Materials Upload Area ──
                        Text('Reference Materials',
                            style: _Tok.fieldLabelStyle),
                        const SizedBox(height: 8),
                        _UploadArea(),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Post Button ──
              Container(
                color: Colors.white.withValues(alpha: 0.9),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Tok.blueRibbon,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isEditing
                            ? 'Update Announcement'
                            : 'Post Announcement',
                        style: _Tok.buttonStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Loading Overlay ──
        if (isLoading)
          const Positioned.fill(
            child: LoadingOverlay(message: 'Posting announcement…'),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE SEGMENT CONTROL
// ═══════════════════════════════════════════════════════════════════════════════

class _TypeSegment extends StatelessWidget {
  const _TypeSegment({
    required this.types,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> types;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _Tok.segmentBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(types.length, (i) {
          final isActive = selectedIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  types[i],
                  style: isActive
                      ? _Tok.segmentActiveStyle
                      : _Tok.segmentInactiveStyle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// THUMBNAIL PICKER
// ═══════════════════════════════════════════════════════════════════════════════

class _BannerMediaPicker extends StatelessWidget {
  const _BannerMediaPicker({
    required this.bannerFiles,
    required this.bannerBytes,
    required this.existingUrls,
    required this.onPick,
    required this.onRemove,
  });

  final List<XFile> bannerFiles;
  final List<Uint8List> bannerBytes;
  final List<String> existingUrls;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  bool get _hasImage => bannerFiles.isNotEmpty || existingUrls.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_hasImage) {
      return Stack(
        children: [
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bannerFiles.isNotEmpty ? bannerFiles.length : existingUrls.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final child = bannerFiles.isNotEmpty
                    ? Image.memory(
                        bannerBytes[i],
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        imageUrl: existingUrls[i],
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 180,
                          height: 180,
                          color: _Tok.athensGray,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 180,
                          height: 180,
                          color: _Tok.athensGray,
                          child: const Icon(Icons.broken_image,
                              size: 32, color: _Tok.grayChateau),
                        ),
                      );
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                );
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                _circleButton(Icons.edit, onPick),
                const SizedBox(width: 8),
                _circleButton(Icons.close, onRemove),
              ],
            ),
          ),
        ],
      );
    }

    // Empty state — upload prompt
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
        decoration: BoxDecoration(
          color: _Tok.blueRibbon.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _Tok.blueRibbon.withValues(alpha: 0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _Tok.blueRibbon.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: _Tok.blueRibbon,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text('Upload Thumbnail', style: _Tok.uploadTitleStyle),
            const SizedBox(height: 4),
            Text('JPG, PNG, WEBP (up to 4 images)', style: _Tok.uploadSubStyle),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class _TweetPreviewCard extends StatelessWidget {
  const _TweetPreviewCard({
    required this.authorName,
    required this.title,
    required this.description,
    required this.type,
    required this.memoryImages,
    required this.networkImages,
  });

  final String authorName;
  final String title;
  final String description;
  final String type;
  final List<Uint8List> memoryImages;
  final List<String> networkImages;

  @override
  Widget build(BuildContext context) {
    final text = [title, description]
        .where((e) => e.isNotEmpty)
        .join('\n\n')
        .trim();

    final hasMemory = memoryImages.isNotEmpty;
    final mediaCount = hasMemory ? memoryImages.length : networkImages.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tok.inputBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: _Tok.athensGray,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: _Tok.grayChateau),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$authorName  ·  @$type',
                  style: _Tok.labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text.isEmpty ? 'Your announcement text preview appears here…' : text,
            style: _Tok.inputTextStyle,
          ),
          if (mediaCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mediaCount,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: hasMemory
                      ? Image.memory(
                          memoryImages[index],
                          width: 190,
                          height: 190,
                          fit: BoxFit.cover,
                        )
                      : CachedNetworkImage(
                          imageUrl: networkImages[index],
                          width: 190,
                          height: 190,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UPLOAD AREA (visual only — placeholder for file picking)
// ═══════════════════════════════════════════════════════════════════════════════

class _UploadArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showPremiumSnackbar(context, 'File upload coming soon');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
        decoration: BoxDecoration(
          color: _Tok.blueRibbon.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _Tok.blueRibbon.withValues(alpha: 0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _Tok.blueRibbon.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: _Tok.blueRibbon,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text('Upload Script or References', style: _Tok.uploadTitleStyle),
            const SizedBox(height: 4),
            Text('PDF, JPG, PNG (Max 10MB)', style: _Tok.uploadSubStyle),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUCCESS SCREEN — "Sent for Approval!"
// ═══════════════════════════════════════════════════════════════════════════════

class AnnouncementSuccessScreen extends StatelessWidget {
  const AnnouncementSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9E8F7),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Decorative circles ──
            Positioned(
              top: 60,
              left: 30,
              child: _Circle(size: 12, color: _Tok.blueRibbon.withValues(alpha: 0.15)),
            ),
            Positioned(
              top: 120,
              right: 50,
              child: _Circle(size: 8, color: _Tok.blueRibbon.withValues(alpha: 0.2)),
            ),
            Positioned(
              top: 200,
              right: 30,
              child: _Circle(size: 6, color: _Tok.blueRibbon.withValues(alpha: 0.12)),
            ),
            Positioned(
              bottom: 180,
              left: 40,
              child: _Circle(size: 10, color: _Tok.blueRibbon.withValues(alpha: 0.1)),
            ),
            Positioned(
              bottom: 120,
              right: 60,
              child: _Circle(size: 14, color: _Tok.blueRibbon.withValues(alpha: 0.08)),
            ),

            // ── Back Button ──
            Positioned(
              top: 12,
              left: 8,
              child: IconButton(
                onPressed: () => context.go('/director-announcements'),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: _Tok.blueRibbon,
                ),
              ),
            ),

            // ── Content ──
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Icon ──
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: _Tok.blueRibbon.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            size: 48,
                            color: _Tok.blueRibbon,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: _Tok.blueRibbon,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    Text(
                      'Sent for Approval!',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _Tok.ebony,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Admin will review your post shortly.\nYou will be notified once it is live.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: _Tok.paleSky,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.go('/director-announcements'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _Tok.blueRibbon,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Go to My Posts',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
