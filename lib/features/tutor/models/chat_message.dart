import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TutorSender { ai, user }

class TutorChatMessage {
  TutorChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
  });

  final String id;
  final TutorSender sender;
  final String text;
  final DateTime timestamp;

  factory TutorChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final senderStr = data['sender'] as String? ?? 'ai';
    final sender = senderStr == 'user' ? TutorSender.user : TutorSender.ai;
    
    DateTime parsedTime;
    if (data['timestamp'] is Timestamp) {
      parsedTime = (data['timestamp'] as Timestamp).toDate();
    } else if (data['timestamp'] is String) {
      parsedTime = DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    return TutorChatMessage(
      id: doc.id,
      sender: sender,
      text: data['text'] as String? ?? '',
      timestamp: parsedTime,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sender': sender.name,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

// Stream provider that yields the chat messages for a specific document.
final tutorMessagesProvider = StreamProvider.family<List<TutorChatMessage>, String?>((ref, documentId) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  // If documentId is null, we can have a general chat or return an empty history.
  // For simplicity, let's keep it document-scoped if documentId is provided,
  // or user-scoped general messages if documentId is null.
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid);

  final query = documentId != null
      ? docRef.collection('documents').doc(documentId).collection('messages')
      : docRef.collection('general_messages');

  return query
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => TutorChatMessage.fromFirestore(doc)).toList();
  });
});
