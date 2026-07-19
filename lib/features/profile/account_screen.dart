import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/responsive_page.dart';
import '../home/models/document.dart';
import '../home/models/study_stats.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  late final TextEditingController _nameController;
  final _schoolController = TextEditingController();
  final _matricController = TextEditingController();
  final _departmentController = TextEditingController();
  final _levelController = TextEditingController();
  bool _credentialsPrefilled = false;

  // The picked avatar, held in memory until Save is tapped. Using bytes
  // (rather than a File path) works uniformly across mobile and web, same
  // as the pattern already used for document uploads in upload_screen.dart.
  Uint8List? _pickedAvatarBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _matricController.dispose();
    _departmentController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      // FileType.image makes file_picker run its own internal image
      // compression step before returning, writing a temp file via
      // FileUtils.compressImage. That write throws "Permission denied" on
      // this device (see FATAL EXCEPTION in FileUtils.createImageFile) and
      // crashes before our code even runs. FileType.custom skips that
      // internal step entirely — we already compress ourselves below.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'webp'],
        withData: true, // ensures .bytes is populated on every platform
      );
      final file = result?.files.firstOrNull;
      if (file == null) return;

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) return;

      // Downscale before it ever touches an ImageProvider — this is the
      // crash fix. Decoding a raw 4000x3000 camera photo just to show a
      // 96x96 circle avatar is what OOMs on lower-RAM devices.
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 512,
        minHeight: 512,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      if (mounted) setState(() => _pickedAvatarBytes = compressed);
    } catch (e) {
      debugPrint('Avatar pick failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick photo: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Fixed path (not per-upload) so old avatars don't pile up in Storage.
      // The `?v=` cache-busting query param on the download URL is what
      // forces cached Image.network widgets elsewhere in the app to fetch
      // the new file instead of showing a stale cached copy at the same
      // URL path — same pattern as CraveNetworkImage.
      if (_pickedAvatarBytes != null) {
        final ref = FirebaseStorage.instance.ref('users/${user.uid}/profile/avatar.jpg');
        await ref.putData(
          _pickedAvatarBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final downloadUrl = await ref.getDownloadURL();
        final bustedUrl =
            '$downloadUrl${downloadUrl.contains('?') ? '&' : '?'}v=${DateTime.now().millisecondsSinceEpoch}';
        await user.updatePhotoURL(bustedUrl);
      }

      if (newName != user.displayName) {
        await user.updateDisplayName(newName);
      }

      await setStudentCredentials(
        user.uid,
        school: _schoolController.text.trim(),
        matricNumber: _matricController.text.trim(),
        department: _departmentController.text.trim(),
        level: _levelController.text.trim(),
      );

      // updateDisplayName/updatePhotoURL don't refresh the cached
      // currentUser synchronously — reload() pulls the update down so the
      // very next read (including currentUserProvider's next emission)
      // reflects it immediately instead of on the next app restart.
      await user.reload();
      ref.invalidate(currentUserProvider);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save changes: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final existingPhotoUrl = user?.photoURL;

    final settingsAsync = ref.watch(userStudySettingsProvider);
    settingsAsync.whenData((settings) {
      if (!_credentialsPrefilled) {
        _credentialsPrefilled = true;
        _schoolController.text = settings.school;
        _matricController.text = settings.matricNumber;
        _departmentController.text = settings.department;
        _levelController.text = settings.level;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: ResponsivePage(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        backgroundImage: _pickedAvatarBytes != null
                            ? MemoryImage(_pickedAvatarBytes!)
                            : (existingPhotoUrl != null
                                ? NetworkImage(existingPhotoUrl)
                                : null) as ImageProvider?,
                        child: _pickedAvatarBytes == null && existingPhotoUrl == null
                            ? const Icon(Symbols.person, size: 48, color: AppColors.primary)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Symbols.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: Text('Tap to change photo', style: AppTextStyles.bodySm()),
              ),
              const SizedBox(height: AppSpacing.xl),

              Text('Name', style: AppTextStyles.labelLg()),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Your name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                user?.email ?? '',
                style: AppTextStyles.bodySm(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),

              Text('Student Credentials', style: AppTextStyles.labelLg()),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _schoolController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'School / Institution',
                  hintText: 'e.g. University of Lagos',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _matricController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Matric / Registration Number',
                  hintText: 'e.g. NUR/20/1234',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _departmentController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  hintText: 'e.g. Nursing Science',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _levelController,
                decoration: const InputDecoration(
                  labelText: 'Level',
                  hintText: 'e.g. 300',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              PrimaryButton(
                label: 'Save Changes',
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}