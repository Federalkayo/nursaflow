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
    this.keyPrinciples,
    this.assessmentHierarchy,
    this.clinicalRedFlags,
    this.takeaways,
  });

  final String id;
  final String title;
  final String course;
  final DocumentStatus status;
  final int pageCount;
  final double progress; // 0..1, quiz/flashcard mastery progress
  
  // Detailed summary fields for Phase 1
  final String? clinicalOverview;
  final List<Map<String, String>>? keyPrinciples;
  final List<Map<String, String>>? assessmentHierarchy;
  final List<Map<String, String>>? clinicalRedFlags;
  final List<String>? takeaways;

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
      keyPrinciples: parseListMap(data['keyPrinciples']),
      assessmentHierarchy: parseListMap(data['assessmentHierarchy']),
      clinicalRedFlags: parseListMap(data['clinicalRedFlags']),
      takeaways: parseListString(data['takeaways']),
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
      'keyPrinciples': keyPrinciples,
      'assessmentHierarchy': assessmentHierarchy,
      'clinicalRedFlags': clinicalRedFlags,
      'takeaways': takeaways,
    };
  }
}

// Stream provider that yields the documents of the currently logged-in user.
final userDocumentsProvider = StreamProvider<List<StudyDocument>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('documents')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => StudyDocument.fromFirestore(doc)).toList();
  });
});

// Stream provider that yields a single document.
final singleDocumentProvider = StreamProvider.family<StudyDocument, String>((ref, documentId) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not logged in');
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
