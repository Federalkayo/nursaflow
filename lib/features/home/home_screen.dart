import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/utils/responsive.dart';
import 'widgets/document_status_card.dart';
import 'widgets/streak_chip.dart';
import 'models/document.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(userDocumentsProvider);
    final user = FirebaseAuth.instance.currentUser;
    final fullName = user?.displayName ?? 'User';
    final firstName = fullName.split(' ').first;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ResponsivePage(
                padBottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good morning,', style: AppTextStyles.bodyMd()),
                        Text(firstName, style: AppTextStyles.headlineLgMobile()),
                      ],
                    ),
                    const StreakChip(days: 5),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ResponsivePage(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    
                    documentsAsync.when(
                      data: (docs) => _QuickStatsRow(docs: docs),
                      loading: () => const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: CircularProgressIndicator(),
                      )),
                      error: (err, stack) => const SizedBox(),
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),

                    // Prominent upload CTA
                    AppCard(
                      onTap: () => context.push('/upload'),
                      color: AppColors.primary,
                      elevated: true,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Symbols.cloud_upload,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Upload New Notes',
                                    style: AppTextStyles.labelLg(color: Colors.white)),
                                const SizedBox(height: 2),
                                Text(
                                  'Turn lecture PDFs into summaries in seconds',
                                  style: AppTextStyles.bodySm(
                                      color: Colors.white.withValues(alpha: 0.85)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Symbols.arrow_forward_ios,
                              color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Documents', style: AppTextStyles.headlineMd()),
                        TextButton(
                          onPressed: () => context.go('/library'),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),

            // Horizontal doc list on mobile, grid on wider screens
            SliverToBoxAdapter(
              child: documentsAsync.when(
                data: (docs) {
                  if (docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Text('No documents uploaded yet.'),
                      ),
                    );
                  }
                  return Responsive.isMobile(context)
                      ? SizedBox(
                          height: 200,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.containerMargin),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (context, i) => SizedBox(
                              width: 220,
                              child: DocumentStatusCard(document: docs[i]),
                            ),
                          ),
                        )
                      : ResponsivePage(
                          child: ResponsiveGrid(
                            childAspectRatio: 1.6,
                            children: [
                              for (final d in docs) DocumentStatusCard(document: d),
                            ],
                          ),
                        );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text('Error: $err'),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: ResponsivePage(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Text("Today's Study Plan", style: AppTextStyles.headlineMd()),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      onTap: () => context.go('/planner'),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PlanRow(
                            icon: Symbols.quiz,
                            title: 'Review Bioethics Quiz',
                            subtitle: 'Ethics & Professionalism • 45 mins',
                          ),
                          Divider(height: AppSpacing.lg),
                          _PlanRow(
                            icon: Symbols.style,
                            title: 'Complete MedSurg Flashcards',
                            subtitle: 'Medical-Surgical I • 1 hour',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.isMobile(context) ? 100 : AppSpacing.xl),
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

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.docs});
  final List<StudyDocument> docs;

  @override
  Widget build(BuildContext context) {
    final totalDocs = docs.length;
    final scoredDocs = docs.where((d) => d.progress > 0).toList();
    final avgScore = scoredDocs.isEmpty 
        ? '0%' 
        : '${(scoredDocs.map((d) => d.progress).reduce((a, b) => a + b) / scoredDocs.length * 100).round()}%';

    return Row(
      children: [
        Expanded(
            child: _StatPill(icon: Symbols.description, value: '$totalDocs', label: 'Docs')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: _StatPill(icon: Symbols.quiz, value: avgScore, label: 'Avg. score')),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
            child: _StatPill(
                icon: Symbols.event_upcoming, value: '3d', label: 'Next exam')),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.headlineMd()),
          Text(label, style: AppTextStyles.labelSm()),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.tertiary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.tertiary, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelLg()),
              Text(subtitle, style: AppTextStyles.bodySm()),
            ],
          ),
        ),
      ],
    );
  }
}
