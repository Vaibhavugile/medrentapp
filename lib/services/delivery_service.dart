import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryService {
  final _db = FirebaseFirestore.instance;

  /// Stages copied 1:1 from web
  static const stages = [
    'assigned',
    'accepted',
    'in_transit',
    'delivered',
    'completed',
    'rejected'
  ];

  static String label(String s) => const {
        'assigned': 'Assigned',
        'accepted': 'Accepted',
        'in_transit': 'Pickup / In transit',
        'delivered': 'Delivered',
        'completed': 'Completed',
        'rejected': 'Rejected',
      }[s] ??
      s;

  // -------------------- helpers --------------------

  int? _toMillis(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    if (v is int) return v;
    if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch;
    return null;
  }

  dynamic _extractExpectedStartDateFromItems(dynamic items) {
    int? bestMs;

    void consider(dynamic val) {
      final ms = _toMillis(val);
      if (ms == null) return;
      if (bestMs == null || ms < bestMs!) bestMs = ms;
    }

    if (items is List) {
      for (final it in items) {
        if (it is! Map) continue;
        consider(it['expectedStartDate']);
        consider(it['expectedstartdate']);
        consider(it['expected_start_date']);
        final sched = it['schedule'] ?? it['scheduling'];
        if (sched is Map) {
          consider(sched['expectedStartDate']);
          consider(sched['expected_start_date']);
        }
      }
    } else if (items is Map) {
      consider(items['expectedStartDate']);
      consider(items['expectedstartdate']);
      consider(items['expected_start_date']);
    }

    return bestMs;
  }

  // -------------------- STREAM --------------------

  /// Stream deliveries where THIS driver is part of drivers[]
  Stream<List<Map<String, dynamic>>> streamDriverDeliveries(String driverId) {
    final q = _db
    .collection('deliveries')
    .where('assignedDriverIds', arrayContains: driverId);


    return q.snapshots().asyncMap((snap) async {
      final out = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = {'id': doc.id, ...?doc.data()};
        final orderId = (data['orderId'] ?? data['order']?['id'])?.toString();

        // attach order
        if (orderId != null && orderId.isNotEmpty) {
          try {
            final o = await _db.doc('orders/$orderId').get();
            data['order'] = {'id': orderId, ...?o.data()};
          } catch (_) {
            data['order'] = {'id': orderId};
          }
        } else {
          data['order'] = data['order'] ?? {};
        }

        final expectedStart =
            _extractExpectedStartDateFromItems(data['items']);
        if (expectedStart != null) {
          data['expectedStartDate'] = expectedStart;
        }

        // merge histories
        List<Map<String, dynamic>> canon(dynamic arr) {
          if (arr is! List) return const [];
          return arr.map<Map<String, dynamic>>((h) {
            final m = (h is Map) ? h : {};
            return {
              'stage': (m['stage'] ?? m['note'] ?? '').toString(),
              'at': m['at'] ?? m['createdAt'],
              'by': (m['by'] ?? '').toString(),
              'note': (m['note'] ?? '').toString(),
            };
          }).toList();
        }

        final merged = [
          ...canon(data['order']?['deliveryHistory']),
          ...canon(data['history']),
        ]..sort((a, b) {
            int toMs(x) {
              final v = x['at'];
              if (v is Timestamp) return v.millisecondsSinceEpoch;
              if (v is int) return v;
              if (v is String) {
                return DateTime.tryParse(v)?.millisecondsSinceEpoch ?? 0;
              }
              return 0;
            }

            return toMs(a).compareTo(toMs(b));
          });

        data['combinedHistory'] = merged;
        out.add(data);
      }
      return out;
    });
  }

  // -------------------- ACCEPT --------------------

  /// Driver accepts delivery. Status becomes `accepted` ONLY when all accept.
 Future<void> acceptDelivery({
  required String deliveryId,
  required String driverId,
}) async {
  final ref = _db.doc('deliveries/$deliveryId');

  await ref.update({
    'status': 'accepted',
    'lastUpdatedBy': driverId,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}


  // -------------------- SCAN --------------------

  /// Any driver can scan assets. Shared global scan state.
  Future<void> addScan({
    required String deliveryId,
    required String assetId,
    required String driverId,
  }) async {
    final ref = _db.doc('deliveries/$deliveryId');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data()!;
      final List expected = List.from(data['expectedAssetIds'] ?? []);
      final Map scanned =
          Map<String, dynamic>.from(data['scannedAssets'] ?? {});

      if (!expected.contains(assetId)) {
        throw Exception('Asset not expected');
      }
      if (scanned.containsKey(assetId)) {
        throw Exception('Asset already scanned');
      }

      scanned[assetId] = {
        'by': driverId,
        'at': DateTime.now().toIso8601String(),
      };

      tx.update(ref, {
        'scannedAssets': scanned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // -------------------- PICKUP COMPLETE --------------------

  /// Auto-move to in_transit when ALL assets scanned
 Future<void> tryCompletePickup({
  required String deliveryId,
  required String leaderDriverId,
}) async {
  final deliveryRef = _db.doc('deliveries/$deliveryId');

  print('🚚 [PICKUP] tryCompletePickup called for $deliveryId');

  await _db.runTransaction((tx) async {
    print('🟡 [PICKUP] Transaction started');

    // 1️⃣ READ DELIVERY
    final deliverySnap = await tx.get(deliveryRef);
    if (!deliverySnap.exists) {
      print('🔴 [PICKUP] Delivery not found');
      return;
    }

    final data = deliverySnap.data()!;
    final String status = (data['status'] ?? '').toString();

    final List<String> expectedAssetIds =
        List<String>.from(data['expectedAssetIds'] ?? []);

    final Map<String, dynamic> scannedAssets =
        Map<String, dynamic>.from(data['scannedAssets'] ?? {});

    print('🟢 [PICKUP] Status=$status');
    print('🟢 [PICKUP] Expected=$expectedAssetIds');
    print('🟢 [PICKUP] Scanned=${scannedAssets.keys.toList()}');

    if (expectedAssetIds.isEmpty) {
      print('⚠️ [PICKUP] No expected assets → EXIT');
      return;
    }

    if (status == 'in_transit' ||
        status == 'delivered' ||
        status == 'completed') {
      print('⚠️ [PICKUP] Already advanced → EXIT');
      return;
    }

    // 2️⃣ VERIFY ALL EXPECTED ASSETS ARE SCANNED
    for (final assetDocId in expectedAssetIds) {
      if (!scannedAssets.containsKey(assetDocId)) {
        print('❌ [PICKUP] Missing scan for $assetDocId → EXIT');
        return;
      }
    }

    print('✅ [PICKUP] All assets scanned');

    // 3️⃣ READ ALL ASSETS FIRST (NO WRITES YET)
    final Map<String, Map<String, dynamic>> assetDataMap = {};

    for (final assetDocId in expectedAssetIds) {
      final assetRef = _db.doc('assets/$assetDocId');
      final assetSnap = await tx.get(assetRef);

      if (!assetSnap.exists) {
        print('⚠️ [PICKUP] Asset $assetDocId missing');
        continue;
      }

      assetDataMap[assetDocId] = assetSnap.data()!;
      print(
        '📦 [PICKUP] Read asset $assetDocId status=${assetSnap.data()!['status']}',
      );
    }

    // 4️⃣ WRITE: CHECK OUT ASSETS
    for (final entry in assetDataMap.entries) {
      final assetDocId = entry.key;
      final assetData = entry.value;

      final currentStatus =
          (assetData['status'] ?? '').toString().toLowerCase();

      if (currentStatus == 'out_for_rental') {
        print('⚠️ [PICKUP] Asset $assetDocId already out_for_rental');
        continue;
      }

      print('✅ [PICKUP] Checking out asset $assetDocId');

      tx.update(_db.doc('assets/$assetDocId'), {
        'status': 'out_for_rental',
        'checkedOutAt': FieldValue.serverTimestamp(),
        'checkedOutByDelivery': deliveryId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 5️⃣ WRITE: UPDATE DELIVERY STAGE
    print('🚀 [PICKUP] Moving delivery to in_transit');

    tx.update(deliveryRef, {
      'status': 'in_transit',
      'leaderDriverId': leaderDriverId,
      'pickedUpAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('🎉 [PICKUP] Transaction completed SUCCESSFULLY');
  });
}
Future<void> tryCompleteReturn({
  required String deliveryId,
  required String leaderDriverId,
}) async {
  final deliveryRef = _db.doc('deliveries/$deliveryId');

  print('🔁 [RETURN] tryCompleteReturn called for $deliveryId');

  await _db.runTransaction((tx) async {
    print('🟡 [RETURN] Transaction started');

    // 1️⃣ READ DELIVERY
    final deliverySnap = await tx.get(deliveryRef);
    if (!deliverySnap.exists) {
      print('🔴 [RETURN] Delivery not found');
      return;
    }

    final data = deliverySnap.data()!;
    final String status = (data['status'] ?? '').toString();

    final List<String> expectedAssetIds =
        List<String>.from(data['expectedAssetIds'] ?? []);

    final Map<String, dynamic> scannedAssets =
        Map<String, dynamic>.from(data['scannedAssets'] ?? {});

    print('🟢 [RETURN] Status=$status');
    print('🟢 [RETURN] Expected=$expectedAssetIds');
    print('🟢 [RETURN] Scanned=${scannedAssets.keys.toList()}');

    if (expectedAssetIds.isEmpty) {
      print('⚠️ [RETURN] No expected assets → EXIT');
      return;
    }

    if (status == 'completed') {
      print('⚠️ [RETURN] Already completed → EXIT');
      return;
    }

    // 2️⃣ VERIFY ALL EXPECTED ASSETS ARE SCANNED
    for (final assetDocId in expectedAssetIds) {
      if (!scannedAssets.containsKey(assetDocId)) {
        print('❌ [RETURN] Missing scan for $assetDocId → EXIT');
        return;
      }
    }

    print('✅ [RETURN] All assets scanned');

    // 3️⃣ READ ALL ASSETS FIRST (NO WRITES YET)
    final Map<String, Map<String, dynamic>> assetDataMap = {};

    for (final assetDocId in expectedAssetIds) {
      final assetRef = _db.doc('assets/$assetDocId');
      final assetSnap = await tx.get(assetRef);

      if (!assetSnap.exists) {
        print('⚠️ [RETURN] Asset $assetDocId missing');
        continue;
      }

      assetDataMap[assetDocId] = assetSnap.data()!;
      print(
        '📦 [RETURN] Read asset $assetDocId status=${assetSnap.data()!['status']}',
      );
    }

    // 4️⃣ WRITE: CHECK IN ASSETS
    for (final entry in assetDataMap.entries) {
      final assetDocId = entry.key;
      final assetData = entry.value;

      final currentStatus =
          (assetData['status'] ?? '').toString().toLowerCase();

      if (currentStatus == 'in_stock') {
        print('⚠️ [RETURN] Asset $assetDocId already in_stock');
        continue;
      }

      print('✅ [RETURN] Checking in asset $assetDocId');

      tx.update(_db.doc('assets/$assetDocId'), {
        'status': 'in_stock',
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkedInByDelivery': deliveryId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 5️⃣ WRITE: COMPLETE DELIVERY
    print('🏁 [RETURN] Completing return delivery');

    tx.update(deliveryRef, {
      'status': 'in_transit',
      'leaderDriverId': leaderDriverId,
      'returnedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('🎉 [RETURN] Transaction completed SUCCESSFULLY');
  });
}


  // -------------------- STAGE UPDATE --------------------

  /// Global stage update (ANY driver triggers → ALL drivers updated)
  Future<void> updateStage({
    required String deliveryId,
    required String newStage,
    String? byDriverId,
  }) async {
    final ref = _db.doc('deliveries/$deliveryId');

    await ref.update({
      'status': newStage,
      'lastUpdatedBy': byDriverId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // -------------------- EXPECTED ASSETS --------------------

  Future<List<Map<String, String>>> loadExpectedAssets(
    Map<String, dynamic> delivery) async {
  final order = (delivery['order'] ?? {}) as Map<String, dynamic>;
  final List dItems = delivery['items'] is List ? delivery['items'] : [];
  final List oItems = order['items'] is List ? order['items'] : [];

  final String deliveryType =
      (delivery['deliveryType'] ?? '').toString().toLowerCase();

  final Map<String, String> assetDocIdToItemName = {};

  // 1️⃣ Prefer delivery items
  for (final it in dItems) {
    final List arr =
        (it is Map && it['assignedAssets'] is List) ? it['assignedAssets'] : [];
    for (final a in arr) {
      assetDocIdToItemName[a.toString()] =
          (it['name'] ?? 'Item').toString();
    }
  }

  // 2️⃣ Fallback to order items
  if (assetDocIdToItemName.isEmpty) {
    for (final it in oItems) {
      final List arr =
          (it is Map && it['assignedAssets'] is List) ? it['assignedAssets'] : [];
      for (final a in arr) {
        assetDocIdToItemName[a.toString()] =
            (it['name'] ?? 'Item').toString();
      }
    }
  }

  // 3️⃣ Final fallback to expectedAssetIds
  if (assetDocIdToItemName.isEmpty) {
    final List exp = delivery['expectedAssetIds'] is List
        ? delivery['expectedAssetIds']
        : [];
    for (final a in exp) {
      assetDocIdToItemName[a.toString()] = 'Item';
    }
  }

  if (assetDocIdToItemName.isEmpty) return const [];

  final expected = <Map<String, String>>[];

  // 4️⃣ Load assets & FILTER BASED ON DELIVERY TYPE
  for (final e in assetDocIdToItemName.entries) {
    try {
      final snap = await _db.doc('assets/${e.key}').get();
      if (!snap.exists) continue;

      final a = snap.data()!;
      final status = (a['status'] ?? '').toString().toLowerCase();

      // 🔑 DELIVERY-TYPE AWARE FILTERING
      if (deliveryType == 'pickup' && status == 'out_for_rental') {
        // pickup: already checked out
        continue;
      }

      if (deliveryType == 'return' && status == 'in_stock') {
        // return: already returned
        continue;
      }

      expected.add({
        'assetDocId': e.key,
        'assetId': (a['assetId'] ?? '').toString(),
        'itemName': e.value,
      });
    } catch (_) {}
  }

  return expected;
}

}
