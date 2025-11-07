import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MarketingService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('marketing');

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final snap = await _col.doc(uid).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...snap.data()!};
  }

  Stream<Map<String, dynamic>?> streamProfile(String uid) {
    return _col.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return {'id': snap.id, ...snap.data()!};
    });
  }

  Future<Map<String, dynamic>> ensureSelfProfile({
    String? name,
    String? phone,
    String? branchId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'No authenticated user';

    final uid = user.uid;
    final ref = _col.doc(uid);
    final now = FieldValue.serverTimestamp();

    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        final data = {
          'uid': uid,
          'name': name ?? (user.displayName ?? 'Marketing User'),
          'phone': phone ?? '',
          'email': user.email ?? '',
          'branchId': branchId ?? '',
          'active': true,
          'role': 'marketing',
          'createdAt': now,
          'createdBy': uid,
          'updatedAt': now,
          'updatedBy': uid,
        };
        tx.set(ref, data);
        return {'id': uid, ...data};
      } else {
        final data = snap.data()!;
        final update = <String, dynamic>{};
        if ((data['name'] ?? '').toString().isEmpty && (user.displayName ?? '').isNotEmpty) {
          update['name'] = user.displayName;
        }
        if ((data['email'] ?? '').toString().isEmpty && (user.email ?? '').isNotEmpty) {
          update['email'] = user.email;
        }
        if (update.isNotEmpty) {
          update['updatedAt'] = now;
          update['updatedBy'] = uid;
          tx.update(ref, update);
        }
        return {'id': uid, ...data, ...update};
      }
    });
  }
}
