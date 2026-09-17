
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  /// FIND MARKETING USER
  /// ---------------------------------------------------------
  ///
  /// We try:
  /// 1. marketing/{userId}
  /// 2. marketing where authUid == userId
  /// 3. marketing where uid == userId
  ///
  /// This supports both your existing and new marketing documents.
  /// ---------------------------------------------------------

  Future<DocumentSnapshot<Map<String, dynamic>>?>
      _findMarketingUser(
    String userId,
  ) async {
    // -------------------------------------------------------
    // 1. Try document ID = Firebase Auth UID
    // -------------------------------------------------------

    final directDoc = await _db
        .collection('marketing')
        .doc(userId)
        .get();

    if (directDoc.exists) {
      return directDoc;
    }

    // -------------------------------------------------------
    // 2. Try authUid
    // -------------------------------------------------------

    final authUidSnap = await _db
        .collection('marketing')
        .where(
          'authUid',
          isEqualTo: userId,
        )
        .limit(1)
        .get();

    if (authUidSnap.docs.isNotEmpty) {
      return authUidSnap.docs.first;
    }

    // -------------------------------------------------------
    // 3. Try uid
    // -------------------------------------------------------

    final uidSnap = await _db
        .collection('marketing')
        .where(
          'uid',
          isEqualTo: userId,
        )
        .limit(1)
        .get();

    if (uidSnap.docs.isNotEmpty) {
      return uidSnap.docs.first;
    }

    return null;
  }

  /// ---------------------------------------------------------
  /// GET ASSIGNED LEAD SOURCE NAMES
  /// ---------------------------------------------------------
  ///
  /// Marketing document contains:
  ///
  /// sourceLabels: [
  ///   "sourceDocumentId1",
  ///   "sourceDocumentId2"
  /// ]
  ///
  /// We resolve those IDs from:
  ///
  /// leadSources/{sourceDocumentId}
  ///
  /// and return:
  ///
  /// ["Google", "Facebook"]
  /// ---------------------------------------------------------

  Future<List<String>> _getMarketingSourceNames(
    String userId,
  ) async {
    final marketingDoc =
        await _findMarketingUser(userId);

    if (marketingDoc == null ||
        !marketingDoc.exists) {
      return [];
    }

    final data = marketingDoc.data();

    if (data == null) {
      return [];
    }

    // -------------------------------------------------------
    // Get source IDs
    // -------------------------------------------------------

    final rawSourceLabels =
        data['sourceLabels'];

    if (rawSourceLabels is! List) {
      return [];
    }

    final sourceIds = rawSourceLabels
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    if (sourceIds.isEmpty) {
      return [];
    }

    // -------------------------------------------------------
    // Resolve source IDs → source names
    // -------------------------------------------------------

    final sourceNames = <String>[];

    for (final sourceId in sourceIds) {
      try {
        final sourceDoc = await _db
            .collection('leadSources')
            .doc(sourceId)
            .get();

        if (!sourceDoc.exists) {
          continue;
        }

        final sourceData = sourceDoc.data();

        final name = sourceData?['name']
            ?.toString()
            .trim();

        if (name != null && name.isNotEmpty) {
          sourceNames.add(name);
        }
      } catch (e) {
        // One invalid source should not break
        // the entire leads stream.
        print(
          'Failed to load lead source $sourceId: $e',
        );
      }
    }

    return sourceNames.toSet().toList();
  }

  /// ---------------------------------------------------------
  /// CONVERT QUERY SNAPSHOT TO MAP
  /// ---------------------------------------------------------

  Map<String, Map<String, dynamic>>
      _snapshotToMap(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final result =
        <String, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      result[doc.id] = {
        'id': doc.id,
        ...doc.data(),
      };
    }

    return result;
  }

  /// ---------------------------------------------------------
  /// SORT LEADS
  /// ---------------------------------------------------------

  List<Map<String, dynamic>> _sortLeads(
    Map<String, Map<String, dynamic>> leads,
  ) {
    final result = leads.values.toList();

    result.sort((a, b) {
      final aTime = a['updatedAt'];
      final bTime = b['updatedAt'];

      DateTime? aDate;
      DateTime? bDate;

      if (aTime is Timestamp) {
        aDate = aTime.toDate();
      }

      if (bTime is Timestamp) {
        bDate = bTime.toDate();
      }

      if (aDate == null && bDate == null) {
        return 0;
      }

      if (aDate == null) {
        return 1;
      }

      if (bDate == null) {
        return -1;
      }

      return bDate.compareTo(aDate);
    });

    return result;
  }

  /// ---------------------------------------------------------
  /// STREAM MY LEADS + ASSIGNED SOURCE LEADS
  /// ---------------------------------------------------------
  ///
  /// Returns:
  ///
  /// 1. Leads created/owned by this user
  ///
  ///     ownerId == userId
  ///
  /// OR
  ///
  /// 2. Leads whose leadSource matches one of the
  ///    marketing user's assigned lead sources.
  ///
  /// No marketingUid is written to leads.
  ///
  /// Both sides are listened to in real time.
  /// ---------------------------------------------------------

  Stream<List<Map<String, dynamic>>> streamMyLeads(
    String ownerId,
  ) {
    late StreamController<
        List<Map<String, dynamic>>> controller;

    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    final queryResults =
        <int, Map<String, Map<String, dynamic>>>{};

    bool closed = false;

    void emitMerged() {
      if (closed) return;

      final merged =
          <String, Map<String, dynamic>>{};

      // Merge all query results.
      //
      // If the same lead appears in both:
      // owner query + source query,
      // the document ID prevents duplicates.

      for (final results in queryResults.values) {
        merged.addAll(results);
      }

      controller.add(
        _sortLeads(merged),
      );
    }

    Future<void> start() async {
      try {
        // ---------------------------------------------------
        // Get source names assigned to marketing user
        // ---------------------------------------------------

        final sourceNames =
            await _getMarketingSourceNames(ownerId);

        if (closed) return;

        // ---------------------------------------------------
        // QUERY 0
        // Own leads
        // ---------------------------------------------------

        final ownQuery = _col.where(
          'ownerId',
          isEqualTo: ownerId,
        );

        final ownSubscription =
            ownQuery.snapshots().listen(
          (snapshot) {
            queryResults[0] =
                _snapshotToMap(snapshot);

            emitMerged();
          },
          onError: (error) {
            print(
              'Own leads stream error: $error',
            );
          },
        );

        subscriptions.add(
          ownSubscription,
        );

        // ---------------------------------------------------
        // No assigned sources
        // ---------------------------------------------------

        if (sourceNames.isEmpty) {
          return;
        }

        // ---------------------------------------------------
        // Firestore whereIn supports max 30 values.
        //
        // Split source names into chunks of 30 so we can
        // support more than 30 sources safely.
        // ---------------------------------------------------

        const chunkSize = 30;

        for (
          int start = 0;
          start < sourceNames.length;
          start += chunkSize
        ) {
          final end =
              (start + chunkSize < sourceNames.length)
                  ? start + chunkSize
                  : sourceNames.length;

          final chunk =
              sourceNames.sublist(start, end);

          final queryIndex =
              start ~/ chunkSize + 1;

          final sourceQuery = _col.where(
            'leadSource',
            whereIn: chunk,
          );

          final sourceSubscription =
              sourceQuery.snapshots().listen(
            (snapshot) {
              queryResults[queryIndex] =
                  _snapshotToMap(snapshot);

              emitMerged();
            },
            onError: (error) {
              print(
                'Source leads stream error: $error',
              );
            },
          );

          subscriptions.add(
            sourceSubscription,
          );
        }
      } catch (e, stackTrace) {
        print(
          'streamMyLeads error: $e',
        );

        print(stackTrace);

        if (!closed) {
          controller.addError(e);
        }
      }
    }

    controller = StreamController<
        List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        start();
      },
      onCancel: () async {
        closed = true;

        for (final subscription
            in subscriptions) {
          await subscription.cancel();
        }

        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  // =========================================================
  // EQUIPMENT ORDERS
  // =========================================================

  /// Returns all equipment orders linked to a lead.
  ///
  /// Firestore:
  /// orders/{orderId}
  ///   leadId == leadId
  Future<List<Map<String, dynamic>>> getEquipmentOrders(
    String leadId,
  ) async {
    final snapshot = await _db
        .collection('orders')
        .where('leadId', isEqualTo: leadId)
        .get();

    final orders = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();

    orders.sort(_compareCreatedAtDescending);

    return orders;
  }

  // =========================================================
  // NURSING / CARETAKER ORDERS + STAFF ASSIGNMENTS
  // =========================================================

  /// Returns all nursing/caretaker orders linked to a lead.
  ///
  /// Firestore:
  /// nursingOrders/{orderId}
  ///   leadId == leadId
  ///
  /// Staff assignments are stored separately:
  /// staffAssignments/{assignmentId}
  ///   orderId == nursingOrderId
  ///
  /// The returned order contains:
  /// order['staffAssignments'] = [...]
  Future<List<Map<String, dynamic>>> getNursingOrders(
    String leadId,
  ) async {
    final snapshot = await _db
        .collection('nursingOrders')
        .where('leadId', isEqualTo: leadId)
        .get();

    final orders = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final order = <String, dynamic>{
        'id': doc.id,
        ...doc.data(),
      };

      try {
        final assignmentSnapshot = await _db
            .collection('staffAssignments')
            .where('orderId', isEqualTo: doc.id)
            .get();

        order['staffAssignments'] =
            assignmentSnapshot.docs.map((assignmentDoc) {
          return {
            'id': assignmentDoc.id,
            ...assignmentDoc.data(),
          };
        }).toList();
      } catch (e) {
        print(
          'Failed to load staff assignments for ${doc.id}: $e',
        );
        order['staffAssignments'] = [];
      }

      orders.add(order);
    }

    orders.sort(_compareCreatedAtDescending);

    return orders;
  }

  // =========================================================
  // REQUIREMENTS
  // =========================================================

  /// Returns all requirements directly linked to a lead.
  ///
  /// Firestore:
  /// requirements/{requirementId}
  ///   leadId == leadId
  Future<List<Map<String, dynamic>>> getRequirements(
    String leadId,
  ) async {
    final snapshot = await _db
        .collection('requirements')
        .where('leadId', isEqualTo: leadId)
        .get();

    final requirements = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();

    requirements.sort(_compareCreatedAtDescending);

    return requirements;
  }

  // =========================================================
  // QUOTATIONS FOR ONE REQUIREMENT
  // =========================================================

  /// Returns every quotation linked to one requirement.
  ///
  /// Firestore:
  /// quotations/{quotationId}
  ///   requirementId == requirementId
  Future<List<Map<String, dynamic>>> getQuotationsForRequirement(
    String requirementId,
  ) async {
    final snapshot = await _db
        .collection('quotations')
        .where(
          'requirementId',
          isEqualTo: requirementId,
        )
        .get();

    final quotations = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();

    quotations.sort(_compareCreatedAtDescending);

    return quotations;
  }

  // =========================================================
  // ALL QUOTATIONS FOR A LEAD
  // =========================================================

  /// Loads:
  ///
  /// Lead
  ///   -> requirements
  ///        -> quotations
  ///
  /// Quotations are intentionally queried by requirementId,
  /// not by leadId.
  ///
  /// Each quotation also receives its parent requirement:
  /// quotation['requirement']
  Future<List<Map<String, dynamic>>> getLeadQuotations(
    String leadId,
  ) async {
    final requirements = await getRequirements(leadId);

    final quotations = <Map<String, dynamic>>[];

    for (final requirement in requirements) {
      final requirementId =
          requirement['id']?.toString().trim();

      if (requirementId == null ||
          requirementId.isEmpty) {
        continue;
      }

      try {
        final requirementQuotations =
            await getQuotationsForRequirement(
          requirementId,
        );

        for (final quotation in requirementQuotations) {
          quotations.add({
            ...quotation,
            'requirement': requirement,
          });
        }
      } catch (e) {
        print(
          'Failed to load quotations for requirement '
          '$requirementId: $e',
        );
      }
    }

    quotations.sort(_compareCreatedAtDescending);

    return quotations;
  }

  // =========================================================
  // CREATED DATE SORT
  // =========================================================

  int _compareCreatedAtDescending(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aTime = a['createdAt'];
    final bTime = b['createdAt'];

    DateTime? aDate;
    DateTime? bDate;

    if (aTime is Timestamp) {
      aDate = aTime.toDate();
    } else if (aTime is DateTime) {
      aDate = aTime;
    } else if (aTime is String) {
      aDate = DateTime.tryParse(aTime);
    }

    if (bTime is Timestamp) {
      bDate = bTime.toDate();
    } else if (bTime is DateTime) {
      bDate = bTime;
    } else if (bTime is String) {
      bDate = DateTime.tryParse(bTime);
    }

    if (aDate == null && bDate == null) {
      return 0;
    }

    if (aDate == null) {
      return 1;
    }

    if (bDate == null) {
      return -1;
    }

    return bDate.compareTo(aDate);
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
