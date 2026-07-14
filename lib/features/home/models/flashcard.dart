import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudyFlashcard {
  const StudyFlashcard({
    required this.id,
    required this.question,
    required this.answer,
    required this.explanation,
  });

  final String id;
  final String question;
  final String answer;
  final String explanation;

  factory StudyFlashcard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StudyFlashcard(
      id: doc.id,
      question: data['question'] as String? ?? '',
      answer: data['answer'] as String? ?? '',
      explanation: data['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      'answer': answer,
      'explanation': explanation,
    };
  }
}

// Stream provider that yields the flashcards for a specific document.
final documentFlashcardsProvider = StreamProvider.family<List<StudyFlashcard>, String>((ref, documentId) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('documents')
      .doc(documentId)
      .collection('flashcards')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => StudyFlashcard.fromFirestore(doc)).toList();
  });
});
