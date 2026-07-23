import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore documents can contain types dart:convert's JsonEncoder doesn't
/// know how to serialize — Timestamp, GeoPoint, DocumentReference — which
/// otherwise throws "Converting object to an encodable object failed".
/// This walks any value returned by a Firestore snapshot and converts those
/// into plain JSON-safe values (ISO 8601 strings, lat/lng maps, path
/// strings) recursively through nested maps and lists.
dynamic _toEncodable(dynamic value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is GeoPoint) return {'latitude': value.latitude, 'longitude': value.longitude};
  if (value is DocumentReference) return value.path;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), _toEncodable(v)));
  if (value is List) return value.map(_toEncodable).toList();
  return value;
}

/// Gathers everything NursaFlow stores about [uid] into a single JSON-ish
/// map, for the "Export my data" action. Reads across every subcollection
/// a user's data lives in (see study_task.dart, document.dart,
/// app_notification.dart, study_stats.dart for where these are written).
Future<Map<String, dynamic>> exportUserData(String uid) async {
  final db = FirebaseFirestore.instance;
  final userRef = db.collection('users').doc(uid);

  final profileDoc = await userRef.get();
  final documentsSnap = await userRef.collection('documents').get();
  final plannerSnap = await userRef.collection('planner').get();
  final notificationsSnap = await userRef.collection('notifications').get();
  final studyLogSnap = await userRef.collection('studyLog').get();

  final authUser = FirebaseAuth.instance.currentUser;

  final raw = {
    'exportedAt': DateTime.now().toIso8601String(),
    'account': {
      'uid': uid,
      'name': authUser?.displayName,
      'email': authUser?.email,
    },
    'profile': profileDoc.data() ?? {},
    'documents': documentsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    'plannerEntries': plannerSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    'notifications': notificationsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    'studyLog': studyLogSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
  };

  return _toEncodable(raw) as Map<String, dynamic>;
}

/// Pretty-printed JSON string version of [exportUserData], ready to copy
/// or share.
Future<String> exportUserDataAsJson(String uid) async {
  final data = await exportUserData(uid);
  return JsonEncoder.withIndent('  ', _toEncodable).convert(data);
}

/// Deletes every Firestore doc NursaFlow has stored for [uid] — all
/// subcollections, then the users/{uid} doc itself — followed by the
/// Firebase Auth account.
///
/// NOTE: Firebase Auth's user.delete() requires a *recent* sign-in. If the
/// session is stale this throws a FirebaseAuthException with code
/// 'requires-recent-login' — callers should catch that specifically and
/// prompt the user to sign out/in again before retrying.
Future<void> deleteAccountAndAllData(String uid) async {
  final db = FirebaseFirestore.instance;
  final userRef = db.collection('users').doc(uid);

  Future<void> deleteDocs(Iterable<DocumentReference> refs) async {
    final list = refs.toList();
    if (list.isEmpty) return;
    // Batches cap at 500 writes — chunk defensively in case a user has an
    // unusually large amount of data (e.g. hundreds of documents/messages).
    for (var i = 0; i < list.length; i += 400) {
      final chunk = list.skip(i).take(400);
      final batch = db.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<void> deleteSubcollection(CollectionReference col) async {
    final snap = await col.get();
    await deleteDocs(snap.docs.map((d) => d.reference));
  }

  // Each uploaded document has its own flashcards/quizzes/messages
  // subcollections (see firestore.rules) that don't get removed just by
  // deleting the parent document — clean those up first.
  final documentsSnap = await userRef.collection('documents').get();
  for (final doc in documentsSnap.docs) {
    await deleteSubcollection(doc.reference.collection('flashcards'));
    await deleteSubcollection(doc.reference.collection('quizzes'));
    await deleteSubcollection(doc.reference.collection('messages'));
  }
  await deleteDocs(documentsSnap.docs.map((d) => d.reference));

  final chatsSnap = await userRef.collection('chats').get();
  for (final chat in chatsSnap.docs) {
    await deleteSubcollection(chat.reference.collection('messages'));
  }
  await deleteDocs(chatsSnap.docs.map((d) => d.reference));

  await deleteSubcollection(userRef.collection('planner'));
  await deleteSubcollection(userRef.collection('notifications'));
  await deleteSubcollection(userRef.collection('studyLog'));
  await deleteSubcollection(userRef.collection('general_messages'));
  await userRef.delete();

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await user.delete();
  }
}