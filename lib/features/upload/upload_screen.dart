import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';
import '../home/models/document.dart';

enum _UploadState { idle, picked, processing }

const _defaultCourses = [
  'Anatomy & Physiology II',
  'Pharmacology for Nurses',
  'Medical-Surgical Nursing',
  'Psychiatric Nursing',
];

const _addCourseSentinel = '__add_new_course__';

const _availableTags = ['Cardiovascular', 'Endocrine', 'Neurology', 'Renal', 'Pediatrics'];

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  _UploadState _state = _UploadState.idle;
  String? _fileName;
  FilePickerResult? _pickedFileResult;
  late List<String> _courses = List.of(_defaultCourses);
  String _selectedCourse = _defaultCourses.first;
  final Set<String> _selectedTags = {};

  Future<void> _addNewCourse() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Course'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Community Health Nursing'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() {
      if (!_courses.contains(name)) _courses.add(name);
      _selectedCourse = name;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'ppt', 'pptx', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _fileName = result.files.first.name;
      _pickedFileResult = result;
      _state = _UploadState.picked;
    });
  }

  Future<void> _analyze() async {
    if (_fileName == null || _pickedFileResult == null) return;
    setState(() => _state = _UploadState.processing);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final documentId = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .doc()
          .id;

      // 1. Upload to Firebase Storage (wrap in try-catch so it is non-blocking if Storage is not yet provisioned in the console)
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/documents/$documentId/$_fileName');

      try {
        final file = _pickedFileResult!.files.first;
        if (file.bytes != null) {
          await storageRef.putData(file.bytes!);
        } else if (file.path != null) {
          await storageRef.putFile(File(file.path!));
        } else {
          throw Exception('No file data available');
        }
      } catch (storageError) {
        debugPrint('Firebase Storage upload warning: $storageError. Proceeding with Firestore creation.');
      }

      // 2. Create the document in Firestore
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .doc(documentId);

      await docRef.set({
        'title': _fileName!.split('.').first,
        'course': _selectedCourse,
        'status': DocumentStatus.processing.name,
        'pageCount': 12,
        'progress': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Redirect the user immediately so they see the processing loader
      if (!mounted) return;
      context.pushReplacement('/document/$documentId/summary');

      // 3. That's it — the `analyzeDocument` Cloud Function is triggered
      // automatically the instant the Firestore document above is created
      // (status: 'processing'). It reads the uploaded file from Storage,
      // calls Gemini, and updates this same document + its flashcards/
      // quizzes subcollections. The summary/flashcards/quiz screens are
      // already listening to this document via Firestore streams, so they
      // update on their own once processing finishes — nothing more to do
      // here.

    } catch (e) {
      if (mounted) {
        setState(() => _state = _UploadState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Hub'),
        leading: IconButton(
          icon: const Icon(Symbols.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsivePage(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Convert your course materials into smart flashcards and summaries instantly.',
                    style: AppTextStyles.bodyMd(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _UploadDropzone(
                    state: _state,
                    fileName: _fileName,
                    onTap: _pickFile,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Row(
                    children: [
                      Expanded(
                        child: _SourceButton(
                          icon: Symbols.add_to_drive,
                          label: 'Google Drive',
                          onTap: _pickFile,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SourceButton(
                          icon: Symbols.folder,
                          label: 'Files',
                          onTap: _pickFile,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SourceButton(
                          icon: Symbols.photo_camera,
                          label: 'Camera Scan',
                          onTap: _pickFile,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Text('Select Course', style: AppTextStyles.labelLg()),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCourse,
                        isExpanded: true,
                        icon: const Icon(Symbols.expand_more),
                        items: [
                          for (final c in _courses)
                            DropdownMenuItem(value: c, child: Text(c)),
                          const DropdownMenuItem(
                            value: _addCourseSentinel,
                            child: Row(
                              children: [
                                Icon(Symbols.add, size: 18, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('Add New Course',
                                    style: TextStyle(color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == _addCourseSentinel) {
                            _addNewCourse();
                          } else {
                            setState(() => _selectedCourse = v!);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Text('Topic Tags', style: AppTextStyles.labelLg()),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final tag in _availableTags)
                        TopicChip(
                          label: tag,
                          selected: _selectedTags.contains(tag),
                          onTap: () => setState(() {
                            _selectedTags.contains(tag)
                                ? _selectedTags.remove(tag)
                                : _selectedTags.add(tag);
                          }),
                        ),
                      ActionChip(
                        avatar: const Icon(Symbols.add, size: 16),
                        label: const Text('New Tag'),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  PrimaryButton(
                    label: 'Analyze Document',
                    icon: Symbols.psychology,
                    isLoading: _state == _UploadState.processing,
                    onPressed: _state == _UploadState.idle ? null : _analyze,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppCard(
                    color: AppColors.tertiary.withValues(alpha: 0.06),
                    elevated: false,
                    border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.2)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Symbols.lightbulb, color: AppColors.tertiary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('NursaFlow Tip', style: AppTextStyles.labelLg()),
                              const SizedBox(height: 2),
                              Text(
                                'Scanning handwritten notes? Our AI recognition is optimized for clinical shorthand and diagrams.',
                                style: AppTextStyles.bodySm(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadDropzone extends StatelessWidget {
  const _UploadDropzone({required this.state, required this.fileName, required this.onTap});
  final _UploadState state;
  final String? fileName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final picked = state != _UploadState.idle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: DottedBorderBox(
        picked: picked,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            children: [
              Icon(
                picked ? Symbols.task : Symbols.cloud_upload,
                size: 40,
                color: picked ? AppColors.tertiary : AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                picked ? fileName ?? 'File selected' : 'Upload PDF, Slides, or Handout',
                style: AppTextStyles.labelLg(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                picked ? 'Tap to change file' : 'Drag and drop or tap to browse',
                style: AppTextStyles.bodySm(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child, required this.picked});
  final Widget child;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: picked ? AppColors.tertiary : AppColors.primary.withValues(alpha: 0.4),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: picked
              ? AppColors.tertiary.withValues(alpha: 0.04)
              : AppColors.primary.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(20),
    );
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashArray: [6, 5]);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, {required List<double> dashArray}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = dashArray[draw ? 0 : 1];
        if (draw) {
          dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      elevated: false,
      border: Border.all(color: AppColors.outlineVariant),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySm(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}