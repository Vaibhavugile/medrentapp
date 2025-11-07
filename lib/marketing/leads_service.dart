import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeadsService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('leads');

  /// Stream leads owned by this user (created/owned by)
  Stream<List<Map<String, dynamic>>> streamMyLeads(String ownerId) {
    return _col
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Create a detailed lead (parity with your web form) + extra 'type'
  Future<String> createLeadDetailed({
    required String ownerId,
    required String ownerName,
    required String customerName,
    required String contactPerson,
    required String phone,
    String? email,
    String? address,
    String? leadSource,
    String? notes,
    String status = 'new',
    String type = 'equipment', // equipment | nursing
  }) async {
    final now = FieldValue.serverTimestamp();
    final doc = await _col.add({
      // core
      'customerName': customerName,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email ?? '',
      'address': address ?? '',
      'leadSource': leadSource ?? '',
      'notes': notes ?? '',
      'status': status,
      // ownership
      'ownerId': ownerId,
      'ownerName': ownerName,
      // NEW: type
      'type': type, // 'equipment' | 'nursing'
      // audit
      'history': [
        {
          'type': 'create',
          'field': null,
          'oldValue': null,
          'newValue': 'Lead created via app',
          'note': notes ?? '',
          'changedBy': ownerId,
          'changedByName': ownerName,
          'ts': DateTime.now().toUtc().toIso8601String(),
        }
      ],
      'createdAt': now,
      'createdBy': ownerId,
      'createdByName': ownerName,
      'updatedAt': now,
      'updatedBy': ownerId,
      'updatedByName': ownerName,
    });
    return doc.id;
  }

  /// Update status (simple)
  Future<void> updateStatus({
    required String leadId,
    required String newStatus,
    required String byUid,
    required String byName,
    String? note,
  }) async {
    final ref = _col.doc(leadId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw 'Lead not found';
      final data = snap.data()!;
      final hist = List.from((data['history'] ?? []) as List);
      hist.add({
        'type': 'status',
        'field': 'status',
        'oldValue': (data['status'] ?? '').toString(),
        'newValue': newStatus,
        if (note != null && note.isNotEmpty) 'note': note,
        'changedBy': byUid,
        'changedByName': byName,
        'ts': DateTime.now().toUtc().toIso8601String(),
      });
      tx.update(ref, {
        'status': newStatus,
        'history': hist,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': byUid,
        'updatedByName': byName,
      });
    });
  }
}
