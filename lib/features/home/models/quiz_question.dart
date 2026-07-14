import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudyQuizQuestion {
  const StudyQuizQuestion({
    required this.id,
    required this.tag,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String id;
  final String tag;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  factory StudyQuizQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final optionsRaw = data['options'] as List<dynamic>? ?? [];
    return StudyQuizQuestion(
      id: doc.id,
      tag: data['tag'] as String? ?? 'GENERAL',
      question: data['question'] as String? ?? '',
      options: optionsRaw.map((e) => e.toString()).toList(),
      correctIndex: (data['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: data['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tag': tag,
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
    };
  }
}

// Stream provider that yields the quiz questions for a specific document.
final documentQuizProvider = StreamProvider.family<List<StudyQuizQuestion>, String>((ref, documentId) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('documents')
      .doc(documentId)
      .collection('quizzes')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => StudyQuizQuestion.fromFirestore(doc)).toList();
  });
});
