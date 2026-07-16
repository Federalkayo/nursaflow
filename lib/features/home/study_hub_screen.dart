import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/utils/responsive.dart';
import 'models/document.dart';

/// Landing point for the "Study" tab — lets the student jump straight into
/// flashcards, a quiz, or the AI tutor for any ready document, without
/// needing to open the document's summary page first.
class StudyHubScreen extends ConsumerWidget {
  const StudyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(userDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Study')),
      body: SafeArea(
        child: ResponsivePage(
          child: ListView(
            children: [
              AppCard(
                onTap: () => context.push('/tutor'),
                color: AppColors.primary,
                child: Row(
                  children: [
                    const Icon(Symbols.psychology, color: Colors.white, size: 28),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ask the AI Tutor',
                              style: AppTextStyles.labelLg(color: Colors.white)),
                          Text('Your 24/7 clinical knowledge partner',
                              style: AppTextStyles.bodySm(
                                  color: Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                    const Icon(Symbols.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Pick a document to study', style: AppTextStyles.headlineMd()),
              const SizedBox(height: AppSpacing.sm),
              
              documentsAsync.when(
                data: (docs) {
                  final ready = docs.where((d) => d.status == DocumentStatus.ready).toList();
                  if (ready.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Column(
                          children: [
                            const Icon(Symbols.folder_open, size: 48, color: AppColors.outlineVariant),
                            const SizedBox(height: AppSpacing.sm),
                            Text('No documents ready to study yet.', style: AppTextStyles.bodyMd()),
                          ],
                        ),
                      ),
                    );
                  }

                  return ResponsiveGrid(
                    childAspectRatio: Responsive.isMobile(context) ? 3.4 : 2.6,
                    children: [
                      for (final d in ready)
                        AppCard(
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.tertiary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Symbols.description,
                                    color: AppColors.tertiary),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.title, style: AppTextStyles.labelLg()),
                                    Text(d.course, style: AppTextStyles.bodySm()),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Symbols.style, color: AppColors.primary),
                                tooltip: 'Flashcards',
                                onPressed: () => context.push('/document/${d.id}/flashcards'),
                              ),
                              IconButton(
                                icon: const Icon(Symbols.quiz, color: AppColors.primary),
                                tooltip: 'Quiz',
                                onPressed: () => context.push('/document/${d.id}/quiz'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SkeletonList(itemCount: 4, showThumbnail: false),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Text('Error: $err'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}