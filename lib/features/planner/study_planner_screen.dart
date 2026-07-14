import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';

class _Task {
  _Task({required this.title, required this.subtitle, this.disabled = false});
  final String title;
  final String subtitle;
  bool done = false;
  final bool disabled;
}

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  int _selectedDay = 2; // Wed
  final _days = const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  final _dates = const [16, 17, 18, 19, 20, 21, 22];

  final _tasks = [
    _Task(title: 'Review Bioethics Quiz', subtitle: 'Ethics & Professionalism • 45 mins'),
    _Task(title: 'Complete MedSurg Flashcards', subtitle: 'Medical-Surgical I • 1 hour'),
    _Task(
      title: 'Pharmacology Review',
      subtitle: 'Scheduled for tomorrow',
      disabled: true,
    ),
  ];

  void _addExamDate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddExamSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _tasks.where((t) => t.done).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Study Planner')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExamDate,
        icon: const Icon(Symbols.add),
        label: const Text('Add Exam Date'),
      ),
      body: SafeArea(
        child: ResponsivePage(
          child: ListView(
            children: [
              Text('September 2026', style: AppTextStyles.headlineLgMobile()),
              Text('Week 36 • Final Prep', style: AppTextStyles.bodyMd()),
              const SizedBox(height: AppSpacing.md),

              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final selected = i == _selectedDay;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDay = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 64,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: selected ? null : AppShadows.level1,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_days[i],
                                style: AppTextStyles.labelSm(
                                    color: selected ? Colors.white70 : AppColors.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text('${_dates[i]}',
                                style: AppTextStyles.headlineMd(
                                    color: selected ? Colors.white : AppColors.onSurface)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Symbols.fact_check, color: AppColors.primary),
                          const SizedBox(height: 4),
                          Text('TASKS DONE', style: AppTextStyles.labelSm()),
                          Text('$done/${_tasks.length}', style: AppTextStyles.headlineLgMobile()),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppCard(
                      color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                      elevated: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Symbols.event_upcoming, color: AppColors.secondary),
                          const SizedBox(height: 4),
                          Text('NEXT EXAM', style: AppTextStyles.labelSm()),
                          Text('3 Days', style: AppTextStyles.headlineLgMobile(color: AppColors.secondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              Text("Today's Study Tasks", style: AppTextStyles.headlineMd()),
              const SizedBox(height: AppSpacing.sm),
              for (final t in _tasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    elevated: !t.disabled,
                    color: t.disabled
                        ? AppColors.surfaceContainerLow
                        : AppColors.surfaceContainerLowest,
                    child: Row(
                      children: [
                        Checkbox(
                          value: t.done,
                          onChanged: t.disabled
                              ? null
                              : (v) => setState(() => t.done = v ?? false),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.title,
                                style: AppTextStyles.labelLg(
                                  color: t.disabled
                                      ? AppColors.outline
                                      : AppColors.onSurface,
                                ),
                              ),
                              Text(t.subtitle, style: AppTextStyles.bodySm()),
                            ],
                          ),
                        ),
                        if (!t.disabled)
                          const Icon(Symbols.more_vert, color: AppColors.outline, size: 20),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),

              AppCard(
                color: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly Progress',
                        style: AppTextStyles.headlineMd(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      "You've completed 60% of your weekly targets. Keep it up!",
                      style: AppTextStyles.bodyMd(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.6,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddExamSheet extends StatelessWidget {
  const _AddExamSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Add Exam Date', style: AppTextStyles.headlineMd()),
            const SizedBox(height: AppSpacing.md),
            const TextField(decoration: InputDecoration(labelText: 'Course')),
            const SizedBox(height: AppSpacing.sm),
            const TextField(decoration: InputDecoration(labelText: 'Exam Date')),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const SizedBox(width: double.infinity, child: Text('Save', textAlign: TextAlign.center)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
