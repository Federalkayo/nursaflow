import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/models/document.dart' show authStateChangesProvider;

/// A single logged study session — created whenever the student taps
/// "Log Study Time" (see home_screen.dart). Kept as individual entries
/// rather than a running counter on the user doc so streak/weekly/daily
/// totals can always be recomputed correctly from source data, with no
/// risk of counters drifting out of sync.
class StudyLogEntry {
  StudyLogEntry({required this.id, required this.minutes, required this.loggedAt});

  final String id;
  final int minutes;
  final DateTime loggedAt;

  factory StudyLogEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final raw = data['loggedAt'];
    return StudyLogEntry(
      id: doc.id,
      minutes: (data['minutes'] as num?)?.toInt() ?? 0,
      loggedAt: raw is Timestamp ? raw.toDate() : DateTime.now(),
    );
  }
}

final studyLogProvider = StreamProvider.autoDispose<List<StudyLogEntry>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(<StudyLogEntry>[]);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('studyLog')
          .orderBy('loggedAt', descending: true)
          .limit(200) // enough history for streak/weekly calcs without unbounded growth
          .snapshots()
          .map((s) => s.docs.map((d) => StudyLogEntry.fromFirestore(d)).toList());
    },
    loading: () => const Stream<List<StudyLogEntry>>.empty(),
    error: (_, __) => Stream.value(<StudyLogEntry>[]),
  );
});

Future<void> logStudyMinutes(String uid, int minutes) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('studyLog')
      .add({'minutes': minutes, 'loggedAt': FieldValue.serverTimestamp()});
}

/// User-level settings: weekly goal (hours) + reminder prefs. Lives on the
/// user doc itself (not a subcollection) since it's a handful of simple
/// scalar fields, not a growing list.
class UserStudySettings {
  UserStudySettings({
    this.weeklyGoalHours = 10,
    this.reminderEnabled = false,
    this.reminderTime = '19:00',
    this.emailNotificationsEnabled = true,
    this.lastReadDocumentId,
    this.school = '',
    this.matricNumber = '',
    this.department = '',
    this.level = '',
  });

  final double weeklyGoalHours;
  final bool reminderEnabled;
  final String reminderTime; // "HH:mm", 24-hour
  final bool emailNotificationsEnabled; // opt-out — see functions/src/reminders.js and weeklyReport.js
  final String? lastReadDocumentId;
  final String school; // institution name
  final String matricNumber; // matriculation / registration number
  final String department; // e.g. "Nursing Science"
  final String level; // e.g. "300", "ND2"

  factory UserStudySettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserStudySettings(
      weeklyGoalHours: (data['weeklyGoalHours'] as num?)?.toDouble() ?? 10,
      reminderEnabled: data['reminderEnabled'] as bool? ?? false,
      reminderTime: data['reminderTime'] as String? ?? '19:00',
      emailNotificationsEnabled: data['emailNotificationsEnabled'] as bool? ?? true,
      lastReadDocumentId: data['lastReadDocumentId'] as String?,
      school: data['school'] as String? ?? '',
      matricNumber: data['matricNumber'] as String? ?? '',
      department: data['department'] as String? ?? '',
      level: data['level'] as String? ?? '',
    );
  }
}

final userStudySettingsProvider = StreamProvider.autoDispose<UserStudySettings>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(UserStudySettings());
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) => UserStudySettings.fromFirestore(doc));
    },
    loading: () => Stream.value(UserStudySettings()),
    error: (_, __) => Stream.value(UserStudySettings()),
  );
});

Future<void> setWeeklyGoalHours(String uid, double hours) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .set({'weeklyGoalHours': hours}, SetOptions(merge: true));
}

Future<void> setReminderSettings(String uid, {required bool enabled, required String time}) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .set({'reminderEnabled': enabled, 'reminderTime': time}, SetOptions(merge: true));
}

Future<void> setEmailNotificationsEnabled(String uid, bool enabled) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .set({'emailNotificationsEnabled': enabled}, SetOptions(merge: true));
}

Future<void> setStudentCredentials(
  String uid, {
  required String school,
  required String matricNumber,
  required String department,
  required String level,
}) {
  return FirebaseFirestore.instance.collection('users').doc(uid).set({
    'school': school,
    'matricNumber': matricNumber,
    'department': department,
    'level': level,
  }, SetOptions(merge: true));
}

Future<void> setLastReadDocument(String uid, String documentId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .set({'lastReadDocumentId': documentId}, SetOptions(merge: true));
}

// ---- Derived stats, computed client-side from raw log entries ----

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int minutesLoggedOn(List<StudyLogEntry> entries, DateTime day) {
  return entries.where((e) => _isSameDay(e.loggedAt, day)).fold(0, (sum, e) => sum + e.minutes);
}

int minutesLoggedBetween(List<StudyLogEntry> entries, DateTime start, DateTime endExclusive) {
  return entries
      .where((e) => e.loggedAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
          e.loggedAt.isBefore(endExclusive))
      .fold(0, (sum, e) => sum + e.minutes);
}

/// Counts consecutive calendar days (ending today or yesterday) that have
/// at least one logged entry. If today has no entry yet, the streak still
/// counts through yesterday (so it doesn't zero out at midnight before
/// the student has had a chance to study today).
int computeStreak(List<StudyLogEntry> entries) {
  if (entries.isEmpty) return 0;
  final days = entries.map((e) => DateTime(e.loggedAt.year, e.loggedAt.month, e.loggedAt.day)).toSet();

  final today = DateTime.now();
  final todayKey = DateTime(today.year, today.month, today.day);
  var cursor = days.contains(todayKey) ? todayKey : todayKey.subtract(const Duration(days: 1));
  if (!days.contains(cursor)) return 0;

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}