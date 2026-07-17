import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/local_notifications_service.dart';
import '../home/models/study_stats.dart';
import 'models/study_task.dart';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class StudyPlannerScreen extends ConsumerStatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  ConsumerState<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends ConsumerState<StudyPlannerScreen> {
  late DateTime _selectedDate;
  late List<DateTime> _weekDates;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    // Monday of the current week through Sunday — computed from the real
    // current date instead of a hardcoded array, so the calendar strip is
    // always showing the actual current week.
    final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    _weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  void _addExamDate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddExamSheet(),
    );
  }

  Future<void> _editWeeklyGoal(BuildContext context, String uid, double current) async {
    final result = await showModalBottomSheet<double>(
      context: context,
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
            Text('Weekly Goal', style: AppTextStyles.headlineMd()),
            const SizedBox(height: AppSpacing.sm),
            Text('How many hours a week are you aiming for?', style: AppTextStyles.bodyMd()),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [5, 7, 10, 14, 20, 25].map((h) {
                return OutlinedButton(
                  onPressed: () => Navigator.pop(context, h.toDouble()),
                  child: Text('${h}h'),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (result != null) {
      await setWeeklyGoalHours(uid, result);
    }
  }

  Future<void> _pickReminderTime(BuildContext context, String uid, String currentTime) async {
    final parts = currentTime.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 19 : 19;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final initial = TimeOfDay(hour: hour, minute: minute);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await setReminderSettings(uid, enabled: true, time: formatted);
      await LocalNotificationsService.scheduleDailyReminder(formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(plannerTasksProvider);
    final logAsync = ref.watch(studyLogProvider);
    final settingsAsync = ref.watch(userStudySettingsProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Study Planner')),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: Responsive.isMobile(context) ? 80.0 : 0.0,
        ),
        child: FloatingActionButton.extended(
          heroTag: null,
          onPressed: _addExamDate,
          icon: const Icon(Symbols.add),
          label: const Text('Add Exam Date'),
        ),
      ),
      body: SafeArea(
        child: ResponsivePage(
          child: tasksAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: SkeletonList(itemCount: 5, showThumbnail: false),
            ),
            error: (err, stack) => Center(child: Text('Error loading planner: $err')),
            data: (allTasks) {
              final regularTasks = allTasks.where((t) => !t.isExam).toList();
              final examTasks = allTasks.where((t) => t.isExam).toList();

              final tasksForSelectedDay =
                  regularTasks.where((t) => _isSameDay(t.dueDate, _selectedDate)).toList();
              final doneCount = tasksForSelectedDay.where((t) => t.done).length;

              final now = DateTime.now();
              final upcomingExams = examTasks.where((t) => t.dueDate.isAfter(now)).toList()
                ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
              final nextExam = upcomingExams.isNotEmpty ? upcomingExams.first : null;
              final daysToNextExam =
                  nextExam != null ? nextExam.dueDate.difference(now).inDays + 1 : null;

              final weekStart = _weekDates.first;
              final logEntries = logAsync.valueOrNull ?? const <StudyLogEntry>[];
              final settings = settingsAsync.valueOrNull ?? UserStudySettings();
              final weekMinutesByDay = [
                for (final d in _weekDates) minutesLoggedOn(logEntries, d)
              ];
              final totalWeekMinutes = weekMinutesByDay.fold(0, (a, b) => a + b);
              final weeklyGoalMinutes = (settings.weeklyGoalHours * 60).round();
              final maxDayMinutes = weekMinutesByDay.isEmpty
                  ? 1
                  : weekMinutesByDay.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);

              return ListView(
                children: [
                  Text(DateFormat('MMMM yyyy').format(_selectedDate),
                      style: AppTextStyles.headlineLgMobile()),
                  Text('Week of ${DateFormat('MMM d').format(weekStart)}',
                      style: AppTextStyles.bodyMd()),
                  const SizedBox(height: AppSpacing.md),

                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _weekDates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
                      itemBuilder: (context, i) {
                        final date = _weekDates[i];
                        final selected = _isSameDay(date, _selectedDate);
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDate = date),
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
                                Text(DateFormat('EEE').format(date).toUpperCase(),
                                    style: AppTextStyles.labelSm(
                                        color: selected ? Colors.white70 : AppColors.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Text('${date.day}',
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
                              Text('$doneCount/${tasksForSelectedDay.length}',
                                  style: AppTextStyles.headlineLgMobile()),
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
                              Text(
                                daysToNextExam != null ? '$daysToNextExam Days' : 'None set',
                                style: AppTextStyles.headlineLgMobile(color: AppColors.secondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Text("Today's Study Tasks", style: AppTextStyles.headlineMd()),
                  const SizedBox(height: AppSpacing.sm),
                  if (tasksForSelectedDay.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text('No tasks scheduled for this day.',
                          style: AppTextStyles.bodyMd()),
                    ),
                  for (final t in tasksForSelectedDay)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        elevated: true,
                        color: AppColors.surfaceContainerLowest,
                        child: Row(
                          children: [
                            Checkbox(
                              value: t.done,
                              onChanged: uid == null
                                  ? null
                                  : (v) => toggleTaskDone(uid, t.id, v ?? false),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.title, style: AppTextStyles.labelLg()),
                                  Text(t.subtitle, style: AppTextStyles.bodySm()),
                                ],
                              ),
                            ),
                            const Icon(Symbols.more_vert, color: AppColors.outline, size: 20),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),

                  // Weekly Goal — real minutes logged this week vs. an
                  // editable target (tap the edit icon to change it).
                  AppCard(
                    color: AppColors.primary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Weekly Goal',
                                style: AppTextStyles.headlineMd(color: Colors.white)),
                            if (uid != null)
                              IconButton(
                                icon: const Icon(Symbols.edit, color: Colors.white, size: 18),
                                onPressed: () => _editWeeklyGoal(context, uid, settings.weeklyGoalHours),
                              ),
                          ],
                        ),
                        Text('${settings.weeklyGoalHours.toStringAsFixed(0)} Hours',
                            style: AppTextStyles.bodyMd(color: Colors.white.withValues(alpha: 0.85))),
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: weeklyGoalMinutes == 0
                                ? 0
                                : (totalWeekMinutes / weeklyGoalMinutes).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(totalWeekMinutes / 60).toStringAsFixed(1)} / ${settings.weeklyGoalHours.toStringAsFixed(0)} Hours',
                          style: AppTextStyles.bodySm(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Weekly Statistics — a simple Mon-Sun bar chart of
                  // minutes actually logged, scaled to the busiest day.
                  Text('Weekly Statistics', style: AppTextStyles.headlineMd()),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: SizedBox(
                      height: 120,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < _weekDates.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      height: 70 * (weekMinutesByDay[i] / maxDayMinutes),
                                      decoration: BoxDecoration(
                                        color: _isSameDay(_weekDates[i], DateTime.now())
                                            ? AppColors.primary
                                            : AppColors.primary.withValues(alpha: 0.35),
                                        borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(4)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('EEE').format(_weekDates[i]).substring(0, 1),
                                      style: AppTextStyles.labelSm(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Study Reminders — Firestore-backed toggle/time, and a
                  // local notification (LocalNotificationsService) armed
                  // for that time on-device. Rescheduled here on every
                  // toggle/time change; re-armed on app start in main.dart
                  // is NOT done today, so a fresh install won't get the
                  // reminder back until the user re-opens this screen.
                  Text('Study Reminders', style: AppTextStyles.headlineMd()),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Daily reminder', style: AppTextStyles.labelLg()),
                              Text(
                                settings.reminderEnabled
                                    ? 'Reminds you at ${settings.reminderTime}'
                                    : 'Off',
                                style: AppTextStyles.bodySm(),
                              ),
                            ],
                          ),
                        ),
                        if (settings.reminderEnabled && uid != null)
                          TextButton(
                            onPressed: () => _pickReminderTime(context, uid, settings.reminderTime),
                            child: Text(settings.reminderTime),
                          ),
                        Switch(
                          value: settings.reminderEnabled,
                          onChanged: uid == null
                              ? null
                              : (v) async {
                                  await setReminderSettings(uid, enabled: v, time: settings.reminderTime);
                                  if (v) {
                                    await LocalNotificationsService.requestPermission();
                                    await LocalNotificationsService.scheduleDailyReminder(
                                        settings.reminderTime);
                                  } else {
                                    await LocalNotificationsService.cancelDailyReminder();
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 96),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AddExamSheet extends StatefulWidget {
  const _AddExamSheet();

  @override
  State<_AddExamSheet> createState() => _AddExamSheetState();
}

class _AddExamSheetState extends State<_AddExamSheet> {
  final _courseController = TextEditingController();
  DateTime? _examDate;
  bool _saving = false;

  @override
  void dispose() {
    _courseController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final course = _courseController.text.trim();
    if (uid == null || course.isEmpty || _examDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a course and pick a date.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await addExamDate(uid, course: course, examDate: _examDate!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
            TextField(
              controller: _courseController,
              decoration: const InputDecoration(labelText: 'Course'),
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Exam Date'),
                child: Text(
                  _examDate != null
                      ? DateFormat('MMM d, yyyy').format(_examDate!)
                      : 'Tap to select a date',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  _saving ? 'Saving…' : 'Save',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}