import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/models/document.dart' show authStateChangesProvider;

/// A single planner entry — either a regular study task (with a due date)
/// or an exam date (isExam: true, dueDate is the exam date itself).
class StudyTask {
  StudyTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.dueDate,
    this.done = false,
    this.isExam = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime dueDate;
  final bool done;
  final bool isExam;

  factory StudyTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawDate = data['dueDate'];
    final dueDate = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();

    return StudyTask(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled',
      subtitle: data['subtitle'] as String? ?? '',
      dueDate: dueDate,
      done: data['done'] as bool? ?? false,
      isExam: data['isExam'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'subtitle': subtitle,
      'dueDate': Timestamp.fromDate(dueDate),
      'done': done,
      'isExam': isExam,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// Stream provider for the current user's planner entries (tasks + exams
// together — the screen filters by isExam/dueDate as needed). Watches
// authStateChangesProvider + autoDispose, same fix as userDocumentsProvider
// and tutorMessagesProvider: without this, a logout/login cycle would keep
// serving a stale/denied listener instead of reconnecting for the new user.
final plannerTasksProvider = StreamProvider.autoDispose<List<StudyTask>>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(<StudyTask>[]);

      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('planner')
          .orderBy('dueDate')
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => StudyTask.fromFirestore(doc)).toList());
    },
    loading: () => const Stream<List<StudyTask>>.empty(),
    error: (_, __) => Stream.value(<StudyTask>[]),
  );
});

/// Toggles a task's done state directly in Firestore — the stream listener
/// picks up the change automatically, no local state juggling needed.
Future<void> toggleTaskDone(String uid, String taskId, bool done) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('planner')
      .doc(taskId)
      .update({'done': done});
}

/// Creates a new exam-date entry in Firestore.
Future<void> addExamDate(String uid, {required String course, required DateTime examDate}) {
  final task = StudyTask(
    id: '',
    title: course,
    subtitle: 'Exam',
    dueDate: examDate,
    isExam: true,
  );
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('planner')
      .add(task.toFirestore());
}