import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/mermaid_view.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/zoomable_image_view.dart';
import '../home/models/document.dart';
import '../home/models/study_stats.dart';

class DocumentSummaryScreen extends ConsumerStatefulWidget {
  const DocumentSummaryScreen({super.key, required this.documentId});
  final String documentId;

  @override
  ConsumerState<DocumentSummaryScreen> createState() => _DocumentSummaryScreenState();
}

class _DocumentSummaryScreenState extends ConsumerState<DocumentSummaryScreen> {
  @override
  void initState() {
    super.initState();
    // Record this as the student's most recently opened document, powering
    // the "Continue Reading" card on the Home screen. Fired once here
    // rather than inside build(), which reruns on every Firestore stream
    // update.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      setLastReadDocument(uid, widget.documentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If the document ID starts with 'new-upload' or 'mock-', we can check the singleDocumentProvider.
    // If not found, singleDocumentProvider will throw, which we catch. We also handle the loading/processing states.
    final documentAsync = ref.watch(singleDocumentProvider(widget.documentId));

    return documentAsync.when(
      data: (doc) {
        if (doc.status == DocumentStatus.limitReached) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Symbols.close),
                onPressed: () => context.go('/home'),
              ),
              title: const Text('Study Hub'),
            ),
            body: SafeArea(
              child: ResponsivePage(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Symbols.workspace_premium, size: 64, color: AppColors.primary),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Free plan limit reached', style: AppTextStyles.headlineMd()),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          "You've reached the free plan's document limit. Upgrade to Premium for unlimited uploads, flashcards, and quizzes.",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMd(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(
                          label: 'Upgrade to Premium',
                          onPressed: () => context.push('/subscription'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (doc.status == DocumentStatus.processing) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Symbols.close),
                onPressed: () => context.go('/home'),
              ),
              title: const Text('Study Hub'),
            ),
            body: SafeArea(
              child: ResponsivePage(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Analyzing notes…', style: AppTextStyles.headlineMd()),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Our AI is reading your materials to extract key clinical insights, flashcards, and quizzes. This usually takes under 10 seconds.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMd(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Setup dynamic summaries with local defaults if empty
        final clinicalOverview = doc.clinicalOverview ??
            'Pediatric nursing focuses on the care of infants, children, and adolescents. Unlike adult care, it requires a deep understanding of developmental stages and family-centered care models.';

        final keyPrinciples = doc.keyPrinciples ?? [
          {
            'title': 'Family-Centered Care',
            'body': "Recognizing the family as the constant in a child's life."
          },
          {
            'title': 'Atraumatic Care',
            'body': 'Minimizing physical and psychological distress during procedures.'
          },
          {
            'title': 'Growth Monitoring',
            'body': 'Continuous assessment using standardized WHO growth charts.'
          }
        ];

        final assessmentHierarchy = doc.assessmentHierarchy ?? [
          {
            'title': 'Vital Signs',
            'body': 'Order: Respiration (count for 1 min) > Pulse > BP > Temperature.'
          },
          {
            'title': 'Physical Exam',
            'body': 'Use play techniques for toddlers; maintain privacy for adolescents.'
          }
        ];

        final clinicalRedFlags = doc.clinicalRedFlags ?? [
          {
            'title': 'Nasal Flaring',
            'body': 'Early sign of respiratory distress.'
          },
          {
            'title': 'Bulging Fontanelle',
            'body': 'Possible increased intracranial pressure.'
          },
          {
            'title': 'Prolonged Capillary Refill',
            'body': 'Critical indicator of dehydration or shock (>3 seconds).'
          }
        ];

        final takeaways = doc.takeaways ?? [
          "Piaget's Stages vs. Clinical Interaction",
          "Fluid Balance Calculations (Holiday-Segar)",
          "Erikson's Developmental Crises"
        ];

        return Scaffold(
          body: SafeArea(
            child: ListView(
              children: [
                ResponsivePage(
                  padBottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Symbols.arrow_back),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Library / ${doc.course}', style: AppTextStyles.bodySm()),
                            Text(doc.title,
                                style: AppTextStyles.headlineLgMobile()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ResponsivePage(
                  padBottom: false,
                  child: _SegmentedTabs(documentId: widget.documentId, active: _Tab.summary),
                ),
                const SizedBox(height: AppSpacing.md),
                ResponsivePage(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (doc.mermaid != null && doc.mermaid!.trim().isNotEmpty) ...[
                          MermaidView(diagram: doc.mermaid!),
                          const SizedBox(height: AppSpacing.md),
                        ] else if (doc.illustrationPath != null) ...[
                          _DocumentIllustration(path: doc.illustrationPath!),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(icon: Symbols.clinical_notes, title: 'Clinical Overview'),
                              const SizedBox(height: AppSpacing.sm),
                              Text.rich(
                                TextSpan(
                                  style: AppTextStyles.bodyMd(color: AppColors.onSurface),
                                  children: [
                                    TextSpan(text: clinicalOverview),
                                  ],
                                ),
                              ),
                              // AI-generated per document (doc.keyQuote), not
                              // a hardcoded quote — hidden entirely when the
                              // document has none rather than showing a
                              // wrong/generic one.
                              if (doc.keyQuote != null && doc.keyQuote!.trim().isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    border: const Border(
                                      left: BorderSide(color: AppColors.primary, width: 3),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '"${doc.keyQuote}"',
                                    style: AppTextStyles.bodyMd(color: AppColors.onSurfaceVariant)
                                        .copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              Text('Key Principles', style: AppTextStyles.labelLg()),
                              const SizedBox(height: AppSpacing.xs),
                              for (final principle in keyPrinciples)
                                _CheckItem(
                                  title: principle['title'] ?? 'Principle',
                                  body: principle['body'] ?? '',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(icon: Symbols.stethoscope, title: 'Assessment Hierarchy'),
                              const SizedBox(height: AppSpacing.sm),
                              // AI-generated per document (doc.assessmentNote),
                              // with a neutral (non-pediatric) fallback when
                              // Groq judged this topic has no real assessment
                              // note to give.
                              Text(
                                (doc.assessmentNote != null && doc.assessmentNote!.trim().isNotEmpty)
                                    ? doc.assessmentNote!
                                    : 'Follow standard assessment order for this topic, moving from least to most invasive where applicable.',
                                style: AppTextStyles.bodyMd(color: AppColors.onSurface),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              for (final step in assessmentHierarchy)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                  child: _InfoRow(
                                    title: step['title'] ?? 'Assessment',
                                    body: step['body'] ?? '',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        AppCard(
                          color: AppColors.errorContainer.withValues(alpha: 0.4),
                          elevated: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Symbols.warning, color: AppColors.error, size: 20),
                                  const SizedBox(width: 6),
                                  Text('Clinical Red Flags',
                                      style: AppTextStyles.labelLg(color: AppColors.onErrorContainer)),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              for (final flag in clinicalRedFlags)
                                _BulletItem(
                                  title: flag['title'] ?? 'Red Flag',
                                  body: flag['body'] ?? '',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        AppCard(
                          color: AppColors.primary,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Symbols.bolt, color: Colors.white, size: 20),
                                  const SizedBox(width: 6),
                                  Text('AI Key Takeaways',
                                      style: AppTextStyles.labelLg(color: Colors.white)),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                "I've summarized the document into these high-yield concepts for your exam.",
                                style: AppTextStyles.bodySm(color: Colors.white.withValues(alpha: 0.85)),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              for (final takeaway in takeaways)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(takeaway,
                                        style: AppTextStyles.bodyMd(color: Colors.white)),
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.xs),
                              SecondaryButton(
                                label: 'Generate Study Guide',
                                expand: false,
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/tutor?documentId=${widget.documentId}'),
            backgroundColor: AppColors.tertiary,
            icon: const Icon(Symbols.psychology, color: Colors.white),
            label: const Text('Ask AI Tutor', style: TextStyle(color: Colors.white)),
          ),
        );
      },
      loading: () => Scaffold(
        body: SafeArea(
          child: ResponsivePage(
            child: AppShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  const SkeletonLine(width: 200, height: 24),
                  const SizedBox(height: AppSpacing.sm),
                  const SkeletonLine(width: 120),
                  const SizedBox(height: AppSpacing.lg),
                  SkeletonBox(width: double.infinity, height: 100, borderRadius: 16),
                  const SizedBox(height: AppSpacing.md),
                  const SkeletonLine(width: double.infinity),
                  const SizedBox(height: AppSpacing.xs),
                  const SkeletonLine(width: double.infinity),
                  const SizedBox(height: AppSpacing.xs),
                  const SkeletonLine(width: 220),
                ],
              ),
            ),
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: ResponsivePage(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: AppSpacing.sm),
                Text('Error loading document detail', style: AppTextStyles.headlineMd()),
                const SizedBox(height: AppSpacing.xs),
                Text('$err', style: AppTextStyles.bodyMd(), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Tab { summary, flashcards, quiz, resources }

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.documentId, required this.active});
  final String documentId;
  final _Tab active;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, _Tab t, VoidCallback onTap) {
      final selected = t == active;
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSm(
                color: selected ? Colors.white : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          tab('Summary', _Tab.summary, () {}),
          tab('Flashcards', _Tab.flashcards,
              () => context.push('/document/$documentId/flashcards')),
          tab('Quiz', _Tab.quiz, () => context.push('/document/$documentId/quiz')),
          tab('Resources', _Tab.resources,
              () => context.push('/document/$documentId/resources')),
        ],
      ),
    );
  }
}

/// Resolves a Firebase Storage path (not a raw URL) to an actual download
/// URL client-side, so access still goes through Storage security rules
/// (only the signed-in owner can read their own path). Shows a skeleton
/// while loading and disappears gracefully if the image ever fails to load
/// rather than breaking the rest of the summary screen. Tappable — opens
/// the shared ZoomableImageView for pinch-to-zoom.
class _DocumentIllustration extends StatelessWidget {
  const _DocumentIllustration({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: FirebaseStorage.instance.ref(path).getDownloadURL(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              height: 200,
              color: AppColors.surfaceContainerLow,
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          // Illustration failed to resolve — just skip it silently, the
          // rest of the summary is still fully usable without it.
          return const SizedBox.shrink();
        }
        final url = snapshot.data!;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: GestureDetector(
            onTap: () => ZoomableImageView.open(context, url),
            child: Stack(
              children: [
                Image.network(
                  url,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                ),
                ExpandButton(onTap: () => ZoomableImageView.open(context, url)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.headlineMd()),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.check_circle, color: AppColors.tertiary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$title: ', style: AppTextStyles.labelLg()),
                  TextSpan(text: body, style: AppTextStyles.bodyMd()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          style: AppTextStyles.bodyMd(color: AppColors.onErrorContainer),
          children: [
            const TextSpan(text: '•  '),
            TextSpan(text: '$title: ', style: AppTextStyles.labelLg(color: AppColors.onErrorContainer)),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelLg()),
          Text(body, style: AppTextStyles.bodySm()),
        ],
      ),
    );
  }
}