
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeadsService {

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('leads');

  /// ---------------------------------------------------------
  /// NORMALIZE PHONE
  /// ---------------------------------------------------------

  String normalizePhone(String phone) {

    var cleaned = phone.replaceAll(
      RegExp(r'\D'),
      '',
    );

    /// Remove India code if exists
    if (cleaned.startsWith('91') &&
        cleaned.length > 10) {

      cleaned = cleaned.substring(2);
    }

    return cleaned;
  }

  /// ---------------------------------------------------------
  /// STREAM MY LEADS
  /// ---------------------------------------------------------

  Stream<List<Map<String, dynamic>>> streamMyLeads(
    String ownerId,
  ) {

    return _col
        .where('ownerId', isEqualTo: ownerId)
        .orderBy(
          'updatedAt',
          descending: true,
        )
        .snapshots()
        .map((q) {

      return q.docs.map((d) {

        return {
          'id': d.id,
          ...d.data(),
        };

      }).toList();

    });
  }

  /// ---------------------------------------------------------
  /// CHECK DUPLICATE
  /// ---------------------------------------------------------

  Future<bool> checkDuplicate({

    required String phone,
    required String type,

  }) async {

    final normalizedPhone =
        normalizePhone(phone);

    final existing = await _col
        .where(
          'normalizedPhone',
          isEqualTo: normalizedPhone,
        )
        .where(
          'type',
          isEqualTo: type,
        )
        .limit(1)
        .get();

    return existing.docs.isNotEmpty;
  }

  /// ---------------------------------------------------------
  /// CREATE LEAD
  /// ---------------------------------------------------------

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

    String type = 'equipment',

  }) async {

    final now =
        FieldValue.serverTimestamp();

    final normalizedPhone =
        normalizePhone(phone);

    /// DUPLICATE CHECK
    final duplicate =
        await checkDuplicate(

      phone: phone,
      type: type,

    );

    final doc = await _col.add({

      /// ---------------------------------------------------
      /// CORE
      /// ---------------------------------------------------

      'customerName':
          customerName.trim(),

      'contactPerson':
          contactPerson.trim(),

      'phone':
          phone.trim(),

      'normalizedPhone':
          normalizedPhone,

      'isDuplicate':
          duplicate,

      'email':
          email?.trim() ?? '',

      'address':
          address?.trim() ?? '',

      'leadSource':
          leadSource?.trim() ?? '',

      'notes':
          notes?.trim() ?? '',

      'status':
          status,

      'type':
          type,

      /// ---------------------------------------------------
      /// OWNERSHIP
      /// ---------------------------------------------------

      'ownerId':
          ownerId,

      'ownerName':
          ownerName,

      /// ---------------------------------------------------
      /// HISTORY
      /// ---------------------------------------------------

      'history': [

        {

          'type': 'create',

          'field': null,

          'oldValue': null,

          'newValue': 'Lead created',

          'note': notes ?? '',

          'changedBy': ownerId,

          'changedByName': ownerName,

          'ts': DateTime.now()
              .toUtc()
              .toIso8601String(),
        }

      ],

      /// ---------------------------------------------------
      /// AUDIT
      /// ---------------------------------------------------

      'createdAt': now,

      'createdBy': ownerId,

      'createdByName': ownerName,

      'updatedAt': now,

      'updatedBy': ownerId,

      'updatedByName': ownerName,

    });

    return doc.id;
  }

  /// ---------------------------------------------------------
  /// UPDATE STATUS
  /// ---------------------------------------------------------

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

      if (!snap.exists) {
        throw 'Lead not found';
      }

      final data = snap.data()!;

      final hist = List.from(
        (data['history'] ?? []) as List,
      );

      hist.add({

        'type': 'status',

        'field': 'status',

        'oldValue':
            (data['status'] ?? '')
                .toString(),

        'newValue':
            newStatus,

        if (note != null &&
            note.isNotEmpty)
          'note': note,

        'changedBy': byUid,

        'changedByName': byName,

        'ts': DateTime.now()
            .toUtc()
            .toIso8601String(),
      });

      tx.update(ref, {

        'status': newStatus,

        'history': hist,

        'updatedAt':
            FieldValue.serverTimestamp(),

        'updatedBy': byUid,

        'updatedByName': byName,

      });
    });
  }

  /// ---------------------------------------------------------
  /// UPDATE LEAD
  /// ---------------------------------------------------------

  Future<void> updateLead({

    required String leadId,

    required String byUid,
    required String byName,

    required Map<String, dynamic> data,

  }) async {

    final ref = _col.doc(leadId);

    data['updatedAt'] =
        FieldValue.serverTimestamp();

    data['updatedBy'] =
        byUid;

    data['updatedByName'] =
        byName;

    if (data.containsKey('phone')) {

      data['normalizedPhone'] =
          normalizePhone(
        data['phone'],
      );
    }

    await ref.update(data);
  }

  /// ---------------------------------------------------------
  /// DELETE LEAD
  /// ---------------------------------------------------------

  Future<void> deleteLead(
    String leadId,
  ) async {

    await _col.doc(leadId).delete();
  }
}

