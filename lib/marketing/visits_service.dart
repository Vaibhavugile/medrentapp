import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class VisitsService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('visits');

  CollectionReference<Map<String, dynamic>> get _daily =>
      _db.collection('daily_stats');

  Stream<List<Map<String, dynamic>>> streamUserVisits(String userId) {
    return _col
        .where('assignedToId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<String> createVisit({
    required String assignedToId,
    required String assignedToName,
    required String createdByUid,
    required String createdByName,
    required String customerName,
    required String phone,
    String? address,
    String? purpose,
    Map<String, dynamic>? plannedGeo, // {lat,lng}
  }) async {
    final now = FieldValue.serverTimestamp();
    final doc = await _col.add({
      'assignedToId': assignedToId,
      'assignedToName': assignedToName,
      'status': 'planned',
      'customerName': customerName,
      'address': address ?? '',
      'contact': {'phone': phone},
      'purpose': purpose ?? '',
      'plannedGeo': plannedGeo,
      'history': [
        {
          'stage': 'planned',
          'by': createdByUid,
          'byName': createdByName,
          'at': DateTime.now().toUtc().toIso8601String(),
          'note': 'Visit created',
        }
      ],
      'createdAt': now,
      'createdBy': createdByUid,
      'createdByName': createdByName,
      'updatedAt': now,
    });

    await _bumpDaily(
      userId: assignedToId,
      userName: assignedToName,
      date: _isoDate(DateTime.now()),
      counters: {'visits_planned': FieldValue.increment(1)},
      event: {
        'type': 'visit_created',
        'visitId': doc.id,
        'at': DateTime.now().toUtc().toIso8601String()
      },
    );

    return doc.id;
  }

  Future<void> startVisit({
    required String visitId,
    required String byUid,
    required String byName,
    required double lat,
    required double lng,
    double? accuracyM,
  }) async {
    final ref = _col.doc(visitId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw 'Visit not found';
      final data = snap.data()!;
      final status = (data['status'] ?? '').toString();
      if (status != 'planned') throw 'Cannot start: not in planned state';

      // ---- SAFE READ plannedGeo ----
      final pgRaw = data['plannedGeo'];
      double? pLat, pLng;
      if (pgRaw is Map) {
        final planned = Map<String, dynamic>.from(pgRaw as Map);
        final latAny = planned['lat'];
        final lngAny = planned['lng'];
        if (latAny is num) pLat = latAny.toDouble();
        if (lngAny is num) pLng = lngAny.toDouble();
      }
      final dist =
          (pLat != null && pLng != null) ? _haversine(pLat!, pLng!, lat, lng) : null;

      final hist = List.from((data['history'] ?? []) as List);
      hist.add({
        'stage': 'started',
        'by': byUid,
        'byName': byName,
        'at': DateTime.now().toUtc().toIso8601String(),
      });

      tx.update(ref, {
        'status': 'started',
        'startedAtMs': DateTime.now().millisecondsSinceEpoch,
        'startedGeo': {
          'lat': lat,
          'lng': lng,
          if (accuracyM != null) 'accuracyM': accuracyM
        },
        if (dist != null) 'distanceFromPlannedStartM': dist,
        'history': hist,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _bumpDailyForVisit(
      visitId,
      counters: {'visits_started': FieldValue.increment(1)},
      addLatLng: {'type': 'visit_started', 'visitId': visitId},
    );
  }

  Future<void> markReached({
    required String visitId,
    required String byUid,
    required String byName,
    required double lat,
    required double lng,
    double? accuracyM,
    String source = 'gps',
    String? note,
  }) async {
    final ref = _col.doc(visitId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw 'Visit not found';
      final data = snap.data()!;
      final status = (data['status'] ?? '').toString();
      if (status != 'started') throw 'Cannot set reached before started';

      // ---- SAFE READ plannedGeo ----
      final pgRaw = data['plannedGeo'];
      double? pLat, pLng;
      if (pgRaw is Map) {
        final planned = Map<String, dynamic>.from(pgRaw as Map);
        final latAny = planned['lat'];
        final lngAny = planned['lng'];
        if (latAny is num) pLat = latAny.toDouble();
        if (lngAny is num) pLng = lngAny.toDouble();
      }
      final dist =
          (pLat != null && pLng != null) ? _haversine(pLat!, pLng!, lat, lng) : null;

      final hist = List.from((data['history'] ?? []) as List);
      hist.add({
        'stage': 'reached',
        'by': byUid,
        'byName': byName,
        'at': DateTime.now().toUtc().toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
      });

      tx.update(ref, {
        'status': 'reached',
        'reachedAtMs': DateTime.now().millisecondsSinceEpoch,
        'reachedGeo': {
          'lat': lat,
          'lng': lng,
          if (accuracyM != null) 'accuracyM': accuracyM
        },
        'reachedSource': source,
        if (dist != null) 'distanceFromPlannedReachM': dist,
        if (note != null && note.isNotEmpty) 'reachedNote': note,
        'history': hist,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _bumpDailyForVisit(
      visitId,
      counters: {'visits_reached': FieldValue.increment(1)},
      addLatLng: {'type': 'visit_reached', 'visitId': visitId},
    );
  }

  Future<String?> completeVisit({
    required String visitId,
    required String byUid,
    required String byName,
    required String outcomeNote,
    bool createLead = true,
    String? leadType, // 'equipment_rental' | 'nursing_service'
    String? leadNeed,
  }) async {
    String? newLeadId;

    await _db.runTransaction((tx) async {
      final ref = _col.doc(visitId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw 'Visit not found';
      final data = snap.data()!;
      final status = (data['status'] ?? '').toString();
      if (status != 'reached') throw 'Complete allowed only after reached';

      final hist = List.from((data['history'] ?? []) as List);
      hist.add({
        'stage': 'done',
        'by': byUid,
        'byName': byName,
        'at': DateTime.now().toUtc().toIso8601String(),
        'note': outcomeNote,
      });

      tx.update(ref, {
        'status': 'done',
        'doneAtMs': DateTime.now().millisecondsSinceEpoch,
        'history': hist,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (createLead) {
        final leadsCol = _db.collection('leads');
        final leadDoc = leadsCol.doc();

        // safe reads
        String phone = '';
        final contactRaw = data['contact'];
        if (contactRaw is Map) {
          final m = Map<String, dynamic>.from(contactRaw as Map);
          final p = m['phone'];
          if (p is String) phone = p;
          if (p is num) phone = p.toString();
        }
        final address = (data['address'] ?? '').toString();

        tx.set(leadDoc, {
          'status': 'new',
          'leadType': leadType ?? 'equipment_rental',
          'contactName': (data['customerName'] ?? '').toString(),
          'phone': phone,
          'address': address,
          'need': leadNeed ?? outcomeNote,
          'source': 'visit',
          'relatedVisitId': visitId,
          'ownerId': byUid,
          'ownerName': byName,
          'history': [
            {
              'stage': 'new',
              'by': byUid,
              'byName': byName,
              'at': DateTime.now().toUtc().toIso8601String(),
              'note': 'Lead created from visit',
            }
          ],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.update(ref, {'relatedLeadId': leadDoc.id});
        newLeadId = leadDoc.id;
      }
    });

    // daily stats bumps (outside tx)
    await _bumpDailyForVisit(
      visitId,
      counters: {'visits_done': FieldValue.increment(1)},
      event: {'type': 'visit_done'},
    );

    if (newLeadId != null) {
      final visit = await _col.doc(visitId).get();
      final userId = (visit.data()?['assignedToId'] ?? '').toString();
      final userName = (visit.data()?['assignedToName'] ?? '').toString();
      await _bumpDaily(
        userId: userId,
        userName: userName,
        date: _isoDate(DateTime.now()),
        counters: {'leads_created': FieldValue.increment(1)},
        event: {
          'type': 'lead_created',
          'leadId': newLeadId,
          'at': DateTime.now().toUtc().toIso8601String()
        },
      );
    }

    return newLeadId;
  }

  Future<void> cancelVisit({
    required String visitId,
    required String byUid,
    required String byName,
    required String reason,
  }) async {
    final ref = _col.doc(visitId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw 'Visit not found';
      final data = snap.data()!;
      final hist = List.from((data['history'] ?? []) as List);
      hist.add({
        'stage': 'cancelled',
        'by': byUid,
        'byName': byName,
        'at': DateTime.now().toUtc().toIso8601String(),
        'note': reason,
      });

      tx.update(ref, {
        'status': 'cancelled',
        'cancelReason': reason,
        'cancelledAtMs': DateTime.now().millisecondsSinceEpoch,
        'history': hist,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _bumpDailyForVisit(
      visitId,
      counters: {'visits_cancelled': FieldValue.increment(1)},
      event: {'type': 'visit_cancelled'},
    );
  }

  // ---------- helpers ----------
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    double toRad(double x) => x * pi / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(toRad(lat1)) *
            cos(toRad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    return 2 * R * asin(sqrt(a));
  }

  String _isoDate(DateTime d) =>
      '${d.toUtc().year.toString().padLeft(4, '0')}-${d.toUtc().month.toString().padLeft(2, '0')}-${d.toUtc().day.toString().padLeft(2, '0')}';

  Future<void> _bumpDaily({
    required String userId,
    required String userName,
    required String date,
    Map<String, dynamic>? counters,
    Map<String, dynamic>? event,
  }) async {
    final id = '${date}_$userId';
    final ref = _daily.doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'date': date,
          'userId': userId,
          'userName': userName,
          'visits_planned': 0,
          'visits_started': 0,
          'visits_reached': 0,
          'visits_done': 0,
          'visits_cancelled': 0,
          'leads_created': 0,
          'leads_won': 0,
          'timeline': [],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      final data = Map<String, dynamic>.from(counters ?? {});
      if (event != null) {
        final tl = List.from((snap.data()?['timeline'] ?? []) as List);
        tl.add({
          ...event,
          'at': (event['at'] ?? DateTime.now().toUtc().toIso8601String()),
        });
        data['timeline'] = tl;
      }
      data['updatedAt'] = FieldValue.serverTimestamp();
      tx.update(ref, data);
    });
  }

  Future<void> _bumpDailyForVisit(
    String visitId, {
    required Map<String, dynamic> counters,
    Map<String, dynamic>? event,
    Map<String, dynamic>? addLatLng,
  }) async {
    final snap = await _col.doc(visitId).get();
    final userId = (snap.data()?['assignedToId'] ?? '').toString();
    final userName = (snap.data()?['assignedToName'] ?? '').toString();
    await _bumpDaily(
      userId: userId,
      userName: userName,
      date: _isoDate(DateTime.now()),
      counters: counters,
      event: addLatLng == null
          ? event
          : {
              ...(event ?? {}),
              ...addLatLng,
              'at': DateTime.now().toUtc().toIso8601String(),
              'lat': ((snap.data()?['status'] ?? '') == 'started')
                  ? (snap.data()?['startedGeo']?['lat'])
                  : (snap.data()?['reachedGeo']?['lat']),
              'lng': ((snap.data()?['status'] ?? '') == 'started')
                  ? (snap.data()?['startedGeo']?['lng'])
                  : (snap.data()?['reachedGeo']?['lng']),
            },
    );
  }
}
