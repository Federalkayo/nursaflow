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

const _courses = [
  'Anatomy & Physiology II',
  'Pharmacology for Nurses',
  'Medical-Surgical Nursing',
  'Psychiatric Nursing',
];

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
  String _selectedCourse = _courses.first;
  final Set<String> _selectedTags = {};

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

      // 3. Simulate processing in the background (3 seconds delay)
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          await docRef.update({
            'status': DocumentStatus.ready.name,
            'clinicalOverview': _generateOverviewFor(_selectedCourse),
            'keyPrinciples': _generatePrinciplesFor(_selectedCourse),
            'assessmentHierarchy': _generateAssessmentFor(_selectedCourse),
            'clinicalRedFlags': _generateRedFlagsFor(_selectedCourse),
            'takeaways': _generateTakeawaysFor(_selectedCourse),
          });

          final flashcardsCol = docRef.collection('flashcards');
          final flashcards = _generateFlashcardsFor(_selectedCourse);
          for (final f in flashcards) {
            await flashcardsCol.add(f);
          }

          final quizCol = docRef.collection('quizzes');
          final quizQuestions = _generateQuizFor(_selectedCourse);
          for (final q in quizQuestions) {
            await quizCol.add(q);
          }
        } catch (_) {}
      });

    } catch (e) {
      if (mounted) {
        setState(() => _state = _UploadState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _generateOverviewFor(String course) {
    switch (course) {
      case 'Pharmacology for Nurses':
        return 'Pharmacology is the study of drug actions on living organisms. For nursing practice, safe administration requires understanding pharmacokinetics, pharmacodynamics, and critical nurse monitoring protocols.';
      case 'Anatomy & Physiology II':
        return 'The renal system regulates fluid volume, electrolyte balance, and acid-base homeostasis. The nephron serves as the functional unit, performing filtration, reabsorption, and secretion.';
      default:
        return 'Pediatric nursing focuses on the care of infants, children, and adolescents. Unlike adult care, it requires a deep understanding of developmental stages and family-centered care models.';
    }
  }

  List<Map<String, String>> _generatePrinciplesFor(String course) {
    switch (course) {
      case 'Pharmacology for Nurses':
        return [
          {'title': 'Right Patient & Drug', 'body': 'Check identifiers and drug labels three times.'},
          {'title': 'Therapeutic Window', 'body': 'Observe dosing schedules to avoid toxicity.'},
          {'title': 'Patient Education', 'body': 'Inform the patient of side effects and compliance needs.'}
        ];
      case 'Anatomy & Physiology II':
        return [
          {'title': 'Renal Blood Flow', 'body': 'Kidneys receive 20-25% of cardiac output.'},
          {'title': 'GFR Autoregulation', 'body': 'Maintains stable filtration rate despite blood pressure changes.'},
          {'title': 'Hormonal Control', 'body': 'Renin, ADH, and Aldosterone regulate system outputs.'}
        ];
      default:
        return [
          {'title': 'Family-Centered Care', 'body': "Recognizing the family as the constant in a child's life."},
          {'title': 'Atraumatic Care', 'body': 'Minimizing physical and psychological distress during procedures.'},
          {'title': 'Growth Monitoring', 'body': 'Continuous assessment using standardized WHO growth charts.'}
        ];
    }
  }

  List<Map<String, String>> _generateAssessmentFor(String course) {
    switch (course) {
      case 'Pharmacology for Nurses':
        return [
          {'title': 'Baseline Vitals', 'body': 'Always verify BP/HR before administering cardioactive agents.'},
          {'title': 'Renal/Hepatic Status', 'body': 'Assess BUN, Creatinine, and AST/ALT for drug clearance capacity.'}
        ];
      case 'Anatomy & Physiology II':
        return [
          {'title': 'Urine Output', 'body': 'Monitor output (normal is >30 mL/hr or 0.5 mL/kg/hr).'},
          {'title': 'Fluid Status', 'body': 'Check for pitting edema and listen for pulmonary crackles.'}
        ];
      default:
        return [
          {'title': 'Vital Signs', 'body': 'Order: Respiration (count for 1 min) > Pulse > BP > Temperature.'},
          {'title': 'Physical Exam', 'body': 'Use play techniques for toddlers; maintain privacy for adolescents.'}
        ];
    }
  }

  List<Map<String, String>> _generateRedFlagsFor(String course) {
    switch (course) {
      case 'Pharmacology for Nurses':
        return [
          {'title': 'Anaphylaxis', 'body': 'Stridor, wheezing, hypotension, or angioedema.'},
          {'title': 'Drug Toxicity', 'body': 'e.g., Digoxin toxicity (visual changes, halo vision).'}
        ];
      case 'Anatomy & Physiology II':
        return [
          {'title': 'Anuria', 'body': 'Output less than 50 mL/24hr indicates acute kidney injury.'},
          {'title': 'Hyperkalemia', 'body': 'Peaked T-waves on ECG (risk of cardiac arrest).'}
        ];
      default:
        return [
          {'title': 'Nasal Flaring', 'body': 'Early sign of respiratory distress.'},
          {'title': 'Bulging Fontanelle', 'body': 'Possible increased intracranial pressure.'},
          {'title': 'Prolonged Capillary Refill', 'body': 'Critical indicator of dehydration or shock (>3 seconds).'}
        ];
    }
  }

  List<String> _generateTakeawaysFor(String course) {
    switch (course) {
      case 'Pharmacology for Nurses':
        return [
          'Half-life Calculations and Steady State',
          'First-Pass Metabolism in Oral Administration',
          'Antidotes list (Naloxone, Protamine Sulfate)'
        ];
      case 'Anatomy & Physiology II':
        return [
          'Glomerular Filtration Rate vs Clearance',
          'Countercurrent Multiplier System mechanism',
          'RAAS Activation Pathways'
        ];
      default:
        return [
          "Piaget's Stages vs. Clinical Interaction",
          "Fluid Balance Calculations (Holiday-Segar)",
          "Erikson's Developmental Crises"
        ];
    }
  }

  List<Map<String, dynamic>> _generateFlashcardsFor(String course) {
    switch (course) {
      case 'Pharmacology for Nurses':
        return [
          {
            'question': 'What is the primary action of beta blockers?',
            'answer': 'Reduce heart rate and blood pressure',
            'explanation': 'They block beta-1 adrenergic receptors, decreasing cardiac contractility and cardiac output.'
          },
          {
            'question': 'What is the therapeutic level of digoxin?',
            'answer': '0.5 – 2.0 ng/mL',
            'explanation': 'Levels above 2.0 ng/mL indicate digitalis toxicity, presenting as nausea and green-yellow halos.'
          }
        ];
      case 'Anatomy & Physiology II':
        return [
          {
            'question': 'Where does most reabsorption occur in the nephron?',
            'answer': 'Proximal Convoluted Tubule (PCT)',
            'explanation': 'About 65% of water, sodium, and 100% of organic nutrients like glucose are reabsorbed here.'
          },
          {
            'question': 'What triggers aldosterone release?',
            'answer': 'Angiotensin II and High Potassium levels',
            'explanation': 'Aldosterone causes the kidneys to retain sodium/water and excrete potassium.'
          }
        ];
      default:
        return [
          {
            'question': 'What is the primary sign of hypovolemia?',
            'answer': 'Tachycardia & Hypotension',
            'explanation': 'A rapid pulse is typically the earliest sign as the heart compensates for low fluid volume.'
          },
          {
            'question': 'What are the stages of wound healing?',
            'answer': 'Hemostasis, Inflammation, Proliferation, and Maturation.',
            'explanation': 'Each stage overlaps but follows this general sequence in normal healing.'
          }
        ];
    }
  }

  List<Map<String, dynamic>> _generateQuizFor(String course) {
    switch (course) {
      case 'Pharmacology for Nurses':
        return [
          {
            'tag': 'SAFETY',
            'question': 'Which drug is the direct antidote for heparin overdose?',
            'options': ['Vitamin K', 'Protamine Sulfate', 'Naloxone', 'Flumazenil'],
            'correctIndex': 1,
            'explanation': 'Protamine sulfate acts as a chemical antagonist, neutralizing heparin activity.'
          }
        ];
      case 'Anatomy & Physiology II':
        return [
          {
            'tag': 'PHYSIOLOGY',
            'question': 'Which cells of the juxtaglomerular apparatus secrete renin?',
            'options': ['Macula Densa cells', 'Granular (Juxtaglomerular) cells', 'Mesangial cells', 'Podocytes'],
            'correctIndex': 1,
            'explanation': 'Granular cells act as baroreceptors and release renin in response to decreased blood pressure.'
          }
        ];
      default:
        return [
          {
            'tag': 'ETHICS & LAW',
            'question': 'A nurse is caring for a patient who refuses a life-saving blood transfusion due to religious beliefs. What is the most appropriate ethical action?',
            'options': [
              'Administer the transfusion anyway, as preserving life is the primary duty of the healthcare team.',
              "Respect the patient's autonomy and document the refusal after ensuring they are fully informed of the risks.",
              "Ask the family to override the patient's decision if the patient is unable to justify their choice rationally.",
              'Seek a court order immediately to mandate the transfusion under the principle of non-maleficence.',
            ],
            'correctIndex': 1,
            'explanation': "Respecting patient autonomy is a core ethical principle — competent adults have the right to refuse treatment, even life-saving treatment, once fully informed."
          }
        ];
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
                        ],
                        onChanged: (v) => setState(() => _selectedCourse = v!),
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
