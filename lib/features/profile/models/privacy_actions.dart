import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  return {
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
}

/// Pretty-printed JSON string version of [exportUserData], ready to copy
/// or share.
Future<String> exportUserDataAsJson(String uid) async {
  final data = await exportUserData(uid);
  return const JsonEncoder.withIndent('  ').convert(data);
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

  Future<void> deleteSubcollection(String name) async {
    final snap = await userRef.collection(name).get();
    if (snap.docs.isEmpty) return;
    final batch = db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  await deleteSubcollection('documents');
  await deleteSubcollection('planner');
  await deleteSubcollection('notifications');
  await deleteSubcollection('studyLog');
  await userRef.delete();

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await user.delete();
  }
}