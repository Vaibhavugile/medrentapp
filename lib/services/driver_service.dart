import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverDoc {
  final String id;
  final Map<String, dynamic> data;
  DriverDoc(this.id, this.data);
}

class DriverService {
  final _db = FirebaseFirestore.instance;

  Future<DriverDoc?> findDriverForUser(User user) async {
    final tries = [
      _db.collection('drivers').where('authUid', isEqualTo: user.uid).limit(1),
      _db.collection('drivers').where('loginEmail', isEqualTo: user.email ?? '').limit(1),
    ];
    for (final q in tries) {
      final snap = await q.get();
      if (snap.docs.isNotEmpty) return DriverDoc(snap.docs.first.id, snap.docs.first.data());
    }
    return null;
  }

  Future<bool> linkByPhoneOrCode(User user, {String? phone, String? driverCode}) async {
    Query<Map<String, dynamic>> q;
    if ((phone ?? '').isNotEmpty) {
      q = _db.collection('drivers').where('phone', isEqualTo: phone).limit(1);
    } else if ((driverCode ?? '').isNotEmpty) {
      q = _db.collection('drivers').where('driverCode', isEqualTo: driverCode).limit(1);
    } else { return false; }

    final s = await q.get();
    if (s.docs.isEmpty) return false;

    final ref = _db.collection('drivers').doc(s.docs.first.id);
    await ref.update({
      'authUid': user.uid,
      'loginEmail': user.email ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }
}
