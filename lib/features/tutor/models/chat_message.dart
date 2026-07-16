import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/models/document.dart' show authStateChangesProvider;

enum TutorSender { ai, user }

class TutorChatMessage {
  TutorChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.imagePath,
  });

  final String id;
  final TutorSender sender;
  final String text;
  final DateTime timestamp;

  // Firebase Storage path (not a download URL) to an AI-generated image
  // attached to this message, e.g. "users/{uid}/chat_images/{id}.png".
  // Resolved to an actual URL client-side via FirebaseStorage.getDownloadURL().
  final String? imagePath;

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
      imagePath: data['imagePath'] as String?,
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

// authStateChangesProvider is imported from ../../home/models/document.dart
// (defined there, reused here) rather than redeclared, so there's exactly
// one shared auth-state stream instead of two separate instances.

// Stream provider that yields the chat messages for a specific document
// (or general chat, when documentId is null).
//
// autoDispose + watching authStateChangesProvider (instead of reading
// FirebaseAuth.instance.currentUser once) means: on logout the stream is
// torn down, and on the next login a brand-new snapshots() subscription is
// opened for the new uid — this is what was previously requiring a manual
// hot restart to recover from after switching accounts.
final tutorMessagesProvider =
    StreamProvider.autoDispose.family<List<TutorChatMessage>, String?>((ref, documentId) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(<TutorChatMessage>[]);

      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      final query = documentId != null
          ? docRef.collection('documents').doc(documentId).collection('messages')
          : docRef.collection('general_messages');

      return query
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => TutorChatMessage.fromFirestore(doc)).toList());
    },
    loading: () => const Stream<List<TutorChatMessage>>.empty(),
    error: (_, __) => Stream.value(<TutorChatMessage>[]),
  );
});