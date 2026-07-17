import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/models/document.dart' show authStateChangesProvider;

// Mirrors how the notification should be handled when tapped. Add new
// cases here as new backend events start writing notifications (payment,
// subscription, streak, etc.) — the UI switches on this to deep-link.
enum NotificationType {
  documentReady,
  tutorReply,
  streak,
  subscription,
  announcement,
  generic,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
    this.refId,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final bool read;
  final DateTime createdAt;

  // Points at the related document/chat/etc, e.g. a documentId. Null for
  // notifications with nowhere to deep-link (announcements).
  final String? refId;

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final typeStr = data['type'] as String? ?? 'generic';
    final type = NotificationType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => NotificationType.generic,
    );
    final ts = data['createdAt'];

    return AppNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: type,
      read: data['read'] as bool? ?? false,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      refId: data['refId'] as String?,
    );
  }
}

// Same autoDispose + authStateChangesProvider pattern as userDocumentsProvider
// in home/models/document.dart — tears the listener down on logout instead
// of leaving a permission-denied stream alive.
final userNotificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(<AppNotification>[]);

      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((snap) =>
              snap.docs.map((d) => AppNotification.fromFirestore(d)).toList());
    },
    loading: () => const Stream<List<AppNotification>>.empty(),
    error: (_, __) => Stream.value(<AppNotification>[]),
  );
});

// Derived unread count — drives the bell badge on the home screen without
// a second Firestore listener.
final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final list = ref.watch(userNotificationsProvider).valueOrNull ?? const [];
  return list.where((n) => !n.read).length;
});

Future<void> markNotificationRead(String uid, String notificationId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .doc(notificationId)
      .update({'read': true});
}

Future<void> markAllNotificationsRead(String uid, List<AppNotification> notifications) {
  final batch = FirebaseFirestore.instance.batch();
  final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');
  for (final n in notifications.where((n) => !n.read)) {
    batch.update(col.doc(n.id), {'read': true});
  }
  return batch.commit();
}
