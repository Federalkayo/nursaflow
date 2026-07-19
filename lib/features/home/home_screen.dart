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
import '../../core/widgets/skeleton.dart';
import '../../core/utils/responsive.dart';
import '../planner/models/study_task.dart';
import 'widgets/document_status_card.dart';
import 'widgets/streak_chip.dart';
import 'models/document.dart';
import 'models/study_stats.dart';
import '../notifications/models/app_notification.dart';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning,';
  if (hour < 17) return 'Good afternoon,';
  return 'Good evening,';
}

// The "what should I do next" line under the name — cheapest way to make
// the header actionable without inventing new data (XP, streak goals,
// etc). Priority: an exam/task due today beats "pick up where you left
// off" beats the generic fallback.
String _headerSubtitle({
  required List<StudyTask> todayTasks,
  required StudyDocument? continueReading,
}) {
  if (todayTasks.isNotEmpty) {
    return todayTasks.length == 1
        ? '1 task due today — let\'s get it done'
        : '${todayTasks.length} tasks due today';
  }
  if (continueReading != null) {
    return 'Pick up "${continueReading.title}" where you left off';
  }
  return 'Ready for today\'s study session?';
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unreadCount});
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Symbols.notifications, size: 22, color: AppColors.primary),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _logStudyTime(BuildContext context, String uid) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Log Study Time', style: AppTextStyles.headlineMd()),
            const SizedBox(height: AppSpacing.sm),
            Text('How long did you just study?', style: AppTextStyles.bodyMd()),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [15, 30, 45, 60, 90, 120].map((m) {
                return OutlinedButton(
                  onPressed: () => Navigator.pop(context, m),
                  child: Text(m < 60 ? '${m}m' : '${m ~/ 60}h${m % 60 == 0 ? '' : ' ${m % 60}m'}'),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (minutes != null) {
      await logStudyMinutes(uid, minutes);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(userDocumentsProvider);
    final studyLogAsync = ref.watch(studyLogProvider);
    final settingsAsync = ref.watch(userStudySettingsProvider);
    final plannerAsync = ref.watch(plannerTasksProvider);

    // Reactive user — currentUserProvider re-emits on updateDisplayName /
    // updatePhotoURL (via user.reload()), unlike a one-off
    // FirebaseAuth.instance.currentUser read. That one-off read is why the
    // avatar/name here went stale after editing them on the Account screen.
    final user = ref.watch(currentUserProvider).valueOrNull ?? FirebaseAuth.instance.currentUser;
    final fullName = user?.displayName ?? 'User';
    final firstName = fullName.split(' ').first;
    final uid = user?.uid;
    final photoUrl = user?.photoURL;

    final logEntries = studyLogAsync.valueOrNull ?? const [];
    final streak = computeStreak(logEntries);
    final todayMinutes = minutesLoggedOn(logEntries, DateTime.now());
    final settings = settingsAsync.valueOrNull ?? UserStudySettings();
    final dailyTargetMinutes = ((settings.weeklyGoalHours * 60) / 7).round();
    final goalProgress =
        dailyTargetMinutes == 0 ? 0.0 : (todayMinutes / dailyTargetMinutes).clamp(0.0, 1.0);

    final docs = documentsAsync.valueOrNull ?? const [];
    StudyDocument? continueReadingDoc;
    if (settings.lastReadDocumentId != null) {
      for (final d in docs) {
        if (d.id == settings.lastReadDocumentId) {
          continueReadingDoc = d;
          break;
        }
      }
    }
    // Captured as a separate `final` so the analyzer can promote it to
    // non-null inside closures (e.g. onTap) below. A mutable local var
    // like `continueReadingDoc` can't be promoted across a closure boundary.
    final continueReading = continueReadingDoc;

    final now = DateTime.now();
    final todayTasks = (plannerAsync.valueOrNull ?? const <StudyTask>[])
        .where((t) => !t.isExam && _isSameDay(t.dueDate, now))
        .toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ResponsivePage(
                padBottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.push('/profile'),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.surfaceContainerHigh,
                                  backgroundImage:
                                      photoUrl != null ? NetworkImage(photoUrl) : null,
                                  child: photoUrl == null
                                      ? const Icon(Symbols.person, size: 22, color: AppColors.primary)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_greeting(), style: AppTextStyles.bodyMd()),
                                    Text(
                                      firstName,
                                      style: AppTextStyles.headlineLgMobile(),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _headerSubtitle(
                                        todayTasks: todayTasks,
                                        continueReading: continueReading,
                                      ),
                                      style: AppTextStyles.bodySm(color: AppColors.outline),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _NotificationBell(unreadCount: ref.watch(unreadNotificationsCountProvider)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    StreakChip(
                      days: streak,
                      suffix: todayMinutes > 0 ? 'Secured for today' : 'Keep it alive today',
                    ),
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
                      loading: () => AppShimmer(
                        child: Row(
                          children: List.generate(
                            3,
                            (i) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i < 2 ? AppSpacing.sm : 0),
                                child: const SkeletonBox(height: 72, borderRadius: 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      error: (err, stack) => const SizedBox(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Today's Goal — real minutes logged today vs. daily
                    // target derived from the weekly goal set in the planner.
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Today's Goal", style: AppTextStyles.headlineMd()),
                              Text(
                                '${(todayMinutes / 60).toStringAsFixed(1)}h / ${(dailyTargetMinutes / 60).toStringAsFixed(1)}h',
                                style: AppTextStyles.bodyMd(),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: goalProgress, minHeight: 8),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (uid != null)
                            OutlinedButton.icon(
                              onPressed: () => _logStudyTime(context, uid),
                              icon: const Icon(Symbols.add, size: 18),
                              label: const Text('Log Study Time'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Continue Reading — last document the student opened.
                    if (continueReading != null) ...[
                      Text('Continue Reading', style: AppTextStyles.headlineMd()),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        onTap: () => context.push('/document/${continueReading.id}/summary'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(continueReading.course, style: AppTextStyles.bodySm()),
                            Text(continueReading.title, style: AppTextStyles.headlineMd()),
                            const SizedBox(height: AppSpacing.xs),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: continueReading.progress.clamp(0.0, 1.0),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('${(continueReading.progress * 100).round()}% Complete',
                                style: AppTextStyles.bodySm()),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

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
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                    vertical: AppSpacing.sm,
                  ),
                  child: const SkeletonRow(itemCount: 3, itemWidth: 220, height: 200),
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
                    Text("Today's Study", style: AppTextStyles.headlineMd()),
                    const SizedBox(height: AppSpacing.sm),
                    if (todayTasks.isEmpty)
                      AppCard(
                        onTap: () => context.go('/planner'),
                        child: Text(
                          'No tasks scheduled for today. Tap to open your planner and add some.',
                          style: AppTextStyles.bodyMd(),
                        ),
                      )
                    else
                      AppCard(
                        onTap: () => context.go('/planner'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < todayTasks.length; i++) ...[
                              if (i > 0) const Divider(height: AppSpacing.lg),
                              _PlanRow(
                                icon: todayTasks[i].isExam ? Symbols.event : Symbols.style,
                                title: todayTasks[i].title,
                                subtitle: todayTasks[i].subtitle,
                                done: todayTasks[i].done,
                              ),
                            ],
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

class _QuickStatsRow extends ConsumerWidget {
  const _QuickStatsRow({required this.docs});
  final List<StudyDocument> docs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalDocs = docs.length;
    final scoredDocs = docs.where((d) => d.progress > 0).toList();
    final avgScore = scoredDocs.isEmpty
        ? '0%'
        : '${(scoredDocs.map((d) => d.progress).reduce((a, b) => a + b) / scoredDocs.length * 100).round()}%';

    // Same "next exam" logic as the Planner screen: soonest upcoming
    // isExam:true entry, days rounded up so an exam later today still
    // reads as "0d" rather than a negative/rounded-down count.
    final tasksAsync = ref.watch(plannerTasksProvider);
    final nextExamValue = tasksAsync.when(
      data: (tasks) {
        final now = DateTime.now();
        final upcomingExams = tasks
            .where((t) => t.isExam && t.dueDate.isAfter(now))
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        if (upcomingExams.isEmpty) return '—';
        final days = upcomingExams.first.dueDate.difference(now).inDays + 1;
        return '${days}d';
      },
      loading: () => '—',
      error: (_, __) => '—',
    );

    return Row(
      children: [
        Expanded(
            child: _StatPill(icon: Symbols.description, value: '$totalDocs', label: 'Docs')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: _StatPill(icon: Symbols.quiz, value: avgScore, label: 'Avg. score')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: _StatPill(
                icon: Symbols.event_upcoming, value: nextExamValue, label: 'Next exam')),
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
  const _PlanRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.done = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;

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
          child: Icon(
            done ? Symbols.check_circle : icon,
            color: AppColors.tertiary,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTextStyles.labelLg(
                      color: done ? AppColors.onSurfaceVariant : AppColors.onSurface)),
              Text(subtitle, style: AppTextStyles.bodySm()),
            ],
          ),
        ),
      ],
    );
  }
}