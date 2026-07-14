import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';
import '../home/models/document.dart';

class DocumentSummaryScreen extends ConsumerWidget {
  const DocumentSummaryScreen({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If the document ID starts with 'new-upload' or 'mock-', we can check the singleDocumentProvider.
    // If not found, singleDocumentProvider will throw, which we catch. We also handle the loading/processing states.
    final documentAsync = ref.watch(singleDocumentProvider(documentId));

    return documentAsync.when(
      data: (doc) {
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
                  child: _SegmentedTabs(documentId: documentId, active: _Tab.summary),
                ),
                const SizedBox(height: AppSpacing.md),
                ResponsivePage(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                  '"The child is not just a small adult. Physiological processes differ significantly in rate and capacity."',
                                  style: AppTextStyles.bodyMd(color: AppColors.onSurfaceVariant)
                                      .copyWith(fontStyle: FontStyle.italic),
                                ),
                              ),
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
                              Text(
                                'To reduce anxiety, always perform the least invasive assessments first. Save painful or intrusive exams (ears, throat) for the end.',
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
            onPressed: () => context.push('/tutor?documentId=$documentId'),
            backgroundColor: AppColors.tertiary,
            icon: const Icon(Symbols.psychology, color: Colors.white),
            label: const Text('Ask AI Tutor', style: TextStyle(color: Colors.white)),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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

enum _Tab { summary, flashcards, quiz, tutor }

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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          tab('Summary', _Tab.summary, () {}),
          tab('Flashcards', _Tab.flashcards,
              () => context.push('/document/$documentId/flashcards')),
          tab('Quiz', _Tab.quiz, () => context.push('/document/$documentId/quiz')),
          tab('Ask Tutor', _Tab.tutor,
              () => context.push('/tutor?documentId=$documentId')),
        ],
      ),
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
