import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DocumentStatus { processing, ready }

class StudyDocument {
  const StudyDocument({
    required this.id,
    required this.title,
    required this.course,
    required this.status,
    this.pageCount = 0,
    this.progress = 0.0,
    this.clinicalOverview,
    this.keyQuote,
    this.keyPrinciples,
    this.assessmentNote,
    this.assessmentHierarchy,
    this.clinicalRedFlags,
    this.takeaways,
    this.illustrationPath,
    this.mermaid,
  });

  final String id;
  final String title;
  final String course;
  final DocumentStatus status;
  final int pageCount;
  final double progress; // 0..1, quiz/flashcard mastery progress

  // Detailed summary fields for Phase 1
  final String? clinicalOverview;

  // A short, topic-specific quote or teaching pearl, AI-generated per
  // document. Null/empty means the summary screen should hide the quote
  // card entirely rather than showing a hardcoded placeholder.
  final String? keyQuote;
  final List<Map<String, String>>? keyPrinciples;

  // 1-sentence practical guidance on approaching this topic's assessment
  // (ordering, technique, etc). Null/empty for topics without a genuine
  // assessment component — summary screen hides the note in that case.
  final String? assessmentNote;
  final List<Map<String, String>>? assessmentHierarchy;
  final List<Map<String, String>>? clinicalRedFlags;
  final List<String>? takeaways;

  // Firebase Storage path (not a download URL) to an AI-generated
  // illustration for this document, e.g. "users/{uid}/documents/{id}/illustration.png".
  // Resolved to an actual URL client-side via FirebaseStorage.getDownloadURL()
  // so access still goes through Storage security rules.
  final String? illustrationPath;

  // Mermaid diagram syntax for process/mechanism topics (e.g. blood
  // circulation), generated instead of an illustration when Groq judges
  // a diagram is the better fit. Null/empty means no diagram for this doc.
  final String? mermaid;

  factory StudyDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final statusStr = data['status'] as String? ?? 'processing';
    final status = DocumentStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => DocumentStatus.processing,
    );

    List<Map<String, String>>? parseListMap(dynamic field) {
      if (field == null) return null;
      if (field is! List) return null;
      return field.map((item) {
        if (item is Map) {
          return item.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
        return <String, String>{};
      }).toList();
    }

    List<String>? parseListString(dynamic field) {
      if (field == null) return null;
      if (field is! List) return null;
      return field.map((e) => e.toString()).toList();
    }

    return StudyDocument(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled',
      course: data['course'] as String? ?? 'General',
      status: status,
      pageCount: (data['pageCount'] as num?)?.toInt() ?? 0,
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      clinicalOverview: data['clinicalOverview'] as String?,
      keyQuote: data['keyQuote'] as String?,
      keyPrinciples: parseListMap(data['keyPrinciples']),
      assessmentNote: data['assessmentNote'] as String?,
      assessmentHierarchy: parseListMap(data['assessmentHierarchy']),
      clinicalRedFlags: parseListMap(data['clinicalRedFlags']),
      takeaways: parseListString(data['takeaways']),
      illustrationPath: data['illustrationPath'] as String?,
      mermaid: data['mermaid'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'course': course,
      'status': status.name,
      'pageCount': pageCount,
      'progress': progress,
      'clinicalOverview': clinicalOverview,
      'keyQuote': keyQuote,
      'keyPrinciples': keyPrinciples,
      'assessmentNote': assessmentNote,
      'assessmentHierarchy': assessmentHierarchy,
      'clinicalRedFlags': clinicalRedFlags,
      'takeaways': takeaways,
    };
  }
}

// Emits the current Firebase user, and re-emits every time sign-in state
// changes (login, logout, token refresh). Every Firestore stream provider
// below watches this instead of reading FirebaseAuth.instance.currentUser
// once — that one-time read was the root cause of documents/chat staying
// permission-denied after a logout -> login cycle: the old provider instance
// (and its now-invalid snapshots() subscription) never got torn down because
// nothing told Riverpod the user had changed.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Stream provider that yields the documents of the currently logged-in user.
// autoDispose + watching authStateChangesProvider means: on logout the
// stream is torn down (uid becomes null -> empty list), and on the next
// login a brand-new snapshots() subscription is opened for the new uid,
// instead of reusing a stale/denied one.
final userDocumentsProvider =
    StreamProvider.autoDispose<List<StudyDocument>>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(<StudyDocument>[]);

      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => StudyDocument.fromFirestore(doc)).toList());
    },
    loading: () => const Stream<List<StudyDocument>>.empty(),
    error: (_, __) => Stream.value(<StudyDocument>[]),
  );
});

// Stream provider that yields a single document.
// Same fix as above: watches authStateChangesProvider + autoDispose so it
// doesn't keep serving a dead listener across a logout/login cycle.
final singleDocumentProvider =
    StreamProvider.autoDispose.family<StudyDocument, String>((ref, documentId) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream<StudyDocument>.error(Exception('User not logged in'));
      }

      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .doc(documentId)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) {
          throw Exception('Document not found');
        }
        return StudyDocument.fromFirestore(snapshot);
      });
    },
    loading: () => const Stream<StudyDocument>.empty(),
    error: (err, __) => Stream<StudyDocument>.error(err),
  );
});

// Seed mock documents array to satisfy references across screen files while transitioning.
const mockDocuments = [
  StudyDocument(
    id: 'mock-peds',
    title: 'Pediatric Care Fundamentals',
    course: 'Pediatrics',
    status: DocumentStatus.ready,
    pageCount: 12,
    progress: 0.8,
  ),
  StudyDocument(
    id: 'mock-renal',
    title: 'Renal Health & Vital Signs',
    course: 'Anatomy & Physiology II',
    status: DocumentStatus.ready,
    pageCount: 8,
    progress: 0.5,
  ),
  StudyDocument(
    id: 'mock-pharm',
    title: 'Intro to Pharmacology',
    course: 'Pharmacology for Nurses',
    status: DocumentStatus.processing,
    pageCount: 15,
    progress: 0.0,
  ),
];