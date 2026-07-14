import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';

class DocumentSummaryScreen extends StatelessWidget {
  const DocumentSummaryScreen({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context) {
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
                        Text('Library / Pediatrics', style: AppTextStyles.bodySm()),
                        Text('Pediatric Care Fundamentals',
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
                                const TextSpan(
                                    text: 'Pediatric nursing focuses on the care of infants, children, and adolescents. Unlike adult care, it requires a deep understanding of '),
                                TextSpan(
                                  text: 'developmental stages',
                                  style: AppTextStyles.bodyMd(color: AppColors.secondary),
                                ),
                                const TextSpan(text: ' and family-centered care models.'),
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
                          const _CheckItem(
                            title: 'Family-Centered Care',
                            body: "Recognizing the family as the constant in a child's life.",
                          ),
                          const _CheckItem(
                            title: 'Atraumatic Care',
                            body: 'Minimizing physical and psychological distress during procedures.',
                          ),
                          const _CheckItem(
                            title: 'Growth Monitoring',
                            body: 'Continuous assessment using standardized WHO growth charts.',
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
                          Text.rich(
                            TextSpan(
                              style: AppTextStyles.bodyMd(color: AppColors.onSurface),
                              children: [
                                const TextSpan(text: 'To reduce anxiety, always perform the '),
                                TextSpan(
                                  text: 'least invasive',
                                  style: AppTextStyles.bodyMd(color: AppColors.secondary),
                                ),
                                const TextSpan(
                                    text: ' assessments first. Save painful or intrusive exams (ears, throat) for the end.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const _InfoRow(
                            title: 'Vital Signs',
                            body: 'Order: Respiration (count for 1 min) > Pulse > BP > Temperature.',
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const _InfoRow(
                            title: 'Physical Exam',
                            body: 'Use play techniques for toddlers; maintain privacy for adolescents.',
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
                          const _BulletItem(
                            title: 'Nasal Flaring',
                            body: 'Early sign of respiratory distress.',
                          ),
                          const _BulletItem(
                            title: 'Bulging Fontanelle',
                            body: 'Possible increased intracranial pressure.',
                          ),
                          const _BulletItem(
                            title: 'Prolonged Capillary Refill',
                            body: 'Critical indicator of dehydration or shock (>3 seconds).',
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
                            "I've summarized the 12-page document into these 3 high-yield concepts for your exam.",
                            style: AppTextStyles.bodySm(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final c in [
                            'Piaget\'s Stages vs. Clinical Interaction',
                            'Fluid Balance Calculations (Holiday-Segar)',
                            "Erikson's Developmental Crises",
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(c,
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
